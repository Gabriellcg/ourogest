import Link from "next/link";
import AuthShell from "@/app/components/AuthShell";
import CadastroForm from "./CadastroForm";

export default function CadastroPage() {
    return (
        <AuthShell
            titulo="Criar conta"
            subtitulo="7 dias grátis com acesso completo. Sem cartão de crédito."
        >
            <CadastroForm />
            <p className="mt-6 text-center text-sm text-grafite/70">
                Já tem conta?{" "}
                <Link href="/login" className="font-medium text-ouro-escuro hover:underline">
                    Entrar
                </Link>
            </p>
        </AuthShell>
    );
}
