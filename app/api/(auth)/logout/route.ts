import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";

export async function POST() {
    try {
        const session = await getSession();
        session.destroy();

        return NextResponse.json(
            { message: "Sessão encerrada com sucesso." },
            { status: 200 }
        );
    } catch (error) {
        console.error("Erro ao terminar sessão", error);
        return NextResponse.json(
            { error: "Erro interno ao terminar a sessão." },
            { status: 500 }
        );
    }
}
