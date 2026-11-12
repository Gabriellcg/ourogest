import {NextRequest, NextResponse} from "next/server";
import {z} from "zod";
import {ResultSetHeader, RowDataPacket} from "mysql2/promise";
import {query, withTransaction} from "@/lib/db";
import {hashPassword, getSession} from "@/lib/auth";

const cadastroSchema = z.object({
    loja_nome: z.string().min(2,"O nome da joalheria deve ter pelo menos 2 caracteres"),
    nome: z.string().min(4, "O seu nome deve ter pelo menos 4 caracteres"),
    email: z.string().email("Informe um e-mail válido"),
    senha: z.string().min(8, "A senha deve ter pelo menos 8 caracteres"),
});

interface LojaRow extends RowDataPacket{
    status_assinatura: "trial" | "ativa" | "vencida" | "bloqueada";
    trial_expira_em: Date;
}

export async function POST(request:NextRequest) {
    try {
        const body = await request.json();

        const validacao = cadastroSchema.safeParse(body);
        if (!validacao.success) {
            const primeiroErro = validacao.error.issues[0]?.message || "Dados invalidos";
            return NextResponse.json({error: primeiroErro}, {status: 400});
        }

        const {loja_nome, nome, email, senha} = validacao.data;
        const emailFormatado = email.toLowerCase().trim();

        const usuarioExistente = await query<RowDataPacket[]>(
            "SELECT ID FROM usuarios WHERE email = ? LIMIT 1",
            [emailFormatado]
        );

        if (usuarioExistente.length > 0) {
            return NextResponse.json(
                {error: "Este e-mail já está cadastrado no sistema."},
                {status: 409}
            );
        }

        const senhaHash = await hashPassword(senha);

        const novoUsuario = await withTransaction(async (conn) => {
            const [resLoja] = await conn.execute<ResultSetHeader>(
                "INSERT INTO lojas (nome) VALUES (?)",
                [loja_nome.trim()]
            );

            const lojaId = resLoja.insertId;

            const [resUsuario] = await conn.execute<ResultSetHeader>(
                "INSERT INTO usuarios (loja_id, nome, email, senha_hash, papel) VALUES (?,?,?,?,'dono')",
                [loja_id, nome.trim(), emailFormatado, senhaHash]
            );

            const usuarioId = resUsuario.insertId;

            await conn.execute(
                "INSERT INTO configuracoes (loja_id) VALUES (?)",
                [lojaId]
            );

            const [lojas] = await conn.query<LojaRow[]>(
                "SELECT status_assinatura, trial_expire_em FROM lojas WHERE id = ?",
                [lojaId]
            );

            return {
                id: usuarioId,
                loja_id: lojaId,
                nome: nome.trim().
                email: emailFormatado,
                loja_nome: loja_nome.trim(),
                papel: "dono" as const,
                status_assinatura: lojas[0].status_assinatura,
                trial_expira_em: lojas[0].trial_expira_em ? new Date(lojas[0].trial_expira_em).toISOString(): null,
            };
        });

        const session = await getSession();
        session.user = novoUsuario;
        await session.save();

        return NextResponse.json(
            {message: "Conta criada com sucesso!", user: novoUsuario},
            {status: 201}
        )
    } catch (error) {
        console.error("Erro ao cadastrar loja:", error);
        return NextResponse.json(
            {error: "Erro interno ao criar a conta. Tente novamente."},
            {status: 500}
        );
    }
}