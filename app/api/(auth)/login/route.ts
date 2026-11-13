import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { RowDataPacket } from "mysql2/promise";
import { query } from "@/lib/db";
import { verifyPassword, getSession } from "@/lib/auth";

const loginSchema = z.object({
    email: z.string().email("Informe um e-mail válido"),
    senha: z.string().min(1, "Informe a senha"),
});

interface UsuarioLojaRow extends RowDataPacket {
    id: number;
    loja_id: number;
    nome: string | null;
    email: string;
    senha_hash: string;
    papel: "dono" | "funcionario";
    loja_nome: string;
    status_assinatura: "trial" | "ativa" | "vencida" | "bloqueada";
    trial_expira_em: Date | null;
}

export async function POST(request: NextRequest) {
    try {
        let body: unknown;
        try {
            body = await request.json();
        } catch {
            return NextResponse.json({ error: "Corpo da requisição inválido." }, { status: 400 });
        }

        const validacao = loginSchema.safeParse(body);
        if (!validacao.success) {
            const primeiroErro = validacao.error.issues[0]?.message || "Dados inválidos";
            return NextResponse.json(
                { error: primeiroErro },
                { status: 400 }
            );
        }

        const { email, senha } = validacao.data;
        const emailFormatado = email.toLowerCase().trim();

        const rows = await query<UsuarioLojaRow[]>(
            `SELECT u.id, u.loja_id, u.nome, u.email, u.senha_hash,
                    u.papel, l.nome AS loja_nome, l.status_assinatura, l.trial_expira_em
             FROM usuarios u
             JOIN lojas l ON l.id = u.loja_id
             WHERE u.email = ? AND u.ativo = 1
             LIMIT 1`,
            [emailFormatado]
        );

        const usuario = rows[0];

        // Mesma mensagem para e-mail inexistente e senha errada (não revela qual dos dois falhou)
        const senhaCorreta = usuario
            ? await verifyPassword(senha, usuario.senha_hash)
            : false;

        if (!usuario || !senhaCorreta) {
            return NextResponse.json(
                { error: "E-mail ou senha incorretos." },
                { status: 401 }
            );
        }

        const session = await getSession();
        session.user = {
            id: usuario.id,
            loja_id: usuario.loja_id,
            nome: usuario.nome ?? "",
            email: usuario.email,
            loja_nome: usuario.loja_nome,
            papel: usuario.papel,
            status_assinatura: usuario.status_assinatura,
            trial_expira_em: usuario.trial_expira_em
                ? new Date(usuario.trial_expira_em).toISOString()
                : null,
        };

        await session.save();

        return NextResponse.json(
            { message: "Login feito com sucesso!", user: session.user },
            { status: 200 }
        );
    } catch (error) {
        console.error("Erro ao fazer login", error);
        return NextResponse.json(
            { error: "Erro interno ao processar o login. Tente novamente." },
            { status: 500 }
        );
    }
}
