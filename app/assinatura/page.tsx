import AuthShell from "@/app/components/AuthShell";
import LogoutButton from "@/app/components/LogoutButton";
import { getCurrentUser } from "@/lib/auth";

// O middleware só deixa chegar aqui quem está logado e com teste vencido, assinatura vencida ou bloqueada
export default async function AssinaturaPage() {
    const user = await getCurrentUser();

    const bloqueada = user?.status_assinatura === "bloqueada";
    const titulo = bloqueada ? "Acesso bloqueado" : "Seu acesso precisa ser ativado";
    const mensagem =
        user?.status_assinatura === "trial"
            ? "O seu teste grátis de 7 dias terminou."
            : bloqueada
              ? "O acesso da sua joalheria está bloqueado."
              : "A assinatura da sua joalheria venceu.";

    // Número do suporte (somente dígitos, com DDI e DDD), definido no .env.local
    const suporte = process.env.NEXT_PUBLIC_SUPORTE_WHATSAPP;

    return (
        <AuthShell titulo={titulo} subtitulo={user ? `Joalheria: ${user.loja_nome}` : undefined}>
            <p className="text-grafite">{mensagem}</p>
            <p className="mt-2 text-sm text-grafite/70">
                Os seus dados continuam guardados. Assim que a assinatura for ativada, o acesso às
                telas volta ao normal.
            </p>

            <div className="mt-6 flex flex-col gap-3">
                {suporte && (
                    <a
                        href={`https://wa.me/${suporte}?text=${encodeURIComponent(
                            "Olá! Quero ativar a assinatura do OuroGest."
                        )}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="rounded-lg bg-ouro px-4 py-2.5 text-center font-medium text-white transition hover:bg-ouro-escuro"
                    >
                        Falar com o suporte
                    </a>
                )}
                <LogoutButton />
            </div>
        </AuthShell>
    );
}
