import type { ReactNode } from "react";
import { redirect } from "next/navigation";
import Sidebar from "@/app/components/Sidebar";
import { getCurrentUser } from "@/lib/auth";
import { diasRestantesTrial } from "@/lib/assinatura";

// Moldura das telas operacionais: menu lateral + conteúdo.
// O middleware já barra quem não está logado; este redirect é a segunda barreira.
export default async function AppLayout({ children }: { children: ReactNode }) {
    const user = await getCurrentUser();
    if (!user) {
        redirect("/login");
    }

    const diasTrial = diasRestantesTrial(user.status_assinatura, user.trial_expira_em);

    return (
        <div className="flex min-h-screen flex-col md:flex-row">
            <Sidebar
                lojaNome={user.loja_nome}
                usuarioNome={user.nome || user.email}
                papel={user.papel}
                diasRestantesTrial={diasTrial}
            />
            <main className="flex-1 p-6 md:p-10">{children}</main>
        </div>
    );
}
