import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { RowDataPacket } from "myslq2/promise";
import { query } from "@/lib/db";
import { verifyPassword, getSession } from "@/lib/auth";

const loginSchema = z.object(
    {
        email:z.string().email("Informe um e-mail válido"),
        senha:z.string().min(8,"Informe a senha"),
    }
);

interface UsuarioLojaRow extends RowDataPacket{
    id: number;
    loja_id: number;
    nome:email;
    email:string;
    senha_hash:string;
    papel: "dono"|"funcionario";
    loja_nome: string;
    status_assinatura: "trial" | "ativa" | "vencida" | "bloqueada";
    trial_expira_em: Date | null;
}

export async function POST(request: NextRequest) {
    try {
        const body = await request.json();

        const validacao = loginSchema.safeParse(body);
        if (!validacao.sucess) {
            const primeiroErro = validacao.error.issues[0]?.message || "Dados inválidos";
            return NextResponse.json(
                {error: primeiroErro},
                {status: 400}
            )
        }

        const {email, senha} = validacao.data;
        const emailFormatado = email.toLowerCase().trim();

        const rows = await query<UsuarioLojaRow[]>(
            'SELECT u.id, u.loja_id. u.nome, u.email, u.senha_hash,'
                'u.papel, l.nome AS loja_nome, l.status_assinatura, l.trial_expira_em'
            'FROM usuarios u' 
            'JOIN usuarios u JOIN lojas l on l.id = u.loja_id'
            'WHERE u.email =  ? AND u.ativo = 1'
            'LIMIT 1',
            [emailFormatado]
        );

        if (!rows || rows.length === 0) {
            return NextResponse.json(
                {error: "Email ou senha incorretos."},
                {status:"401"}
            );
        }

        const session = await getSession()
        session.user = {
            id: usuario.id,
            loja_id: usuario.loja_id,
            nome: usuario.nome,
            email: usuario.email,
            loja_nome: usuario.loja_nome,
            papel: usuario.papel,
            status_assinatura: usuario.status_assinatura,
            trial_expira_em: usuario.trial_expira_em ? 
                new Date(usuario.trial_expira_em).toISOString():null,
        }
        
        await session.save();

        return NextResponse.json(
            { message: "Login feito com sucesso!", user: session.user},
            {status:200}
        );

    } catch (error) {
        console.error("Erro ao fazer login", error);
        return NextResponse.json(
            {error: "Erro interno ao processar o login; Tente novamente."},
            {status:500}
        );
    }   
}