import Link from "next/link";
import AuthShell from "@/app/components/AuthShell";
import LoginForm from "./LoginForm";

export default function LoginPage() {
    return (
        <AuthShell titulo="Entrar" subtitulo="Acesse a gestão da sua joalheria.">
            <LoginForm />
            <p className="mt-6 text-center text-sm text-grafite/70">
                Ainda não tem conta?{" "}
                <Link href="/cadastro" className="font-medium text-ouro-escuro hover:underline">
                    Teste grátis por 7 dias
                </Link>
            </p>
        </AuthShell>
    );
}
