import LogoutButton from "@/app/components/LogoutButton";
import { getCurrentUser } from "@/lib/auth";

// Página provisória: a calculadora de gramas será feita na Fase 2
export default async function CalculadoraPage() {
    const user = await getCurrentUser();

    return (
        <main className="mx-auto max-w-2xl px-4 py-16">
            <h1 className="text-2xl font-semibold text-grafite">Calculadora</h1>
            <p className="mt-2 text-grafite/70">
                Olá, {user?.nome || "bem-vindo"}! Você está logado em {user?.loja_nome}. A calculadora
                chega na Fase 2.
            </p>
            <LogoutButton className="mt-6" />
        </main>
    );
}
