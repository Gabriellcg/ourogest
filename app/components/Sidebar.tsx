"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import LogoutButton from "./LogoutButton";

interface ItemMenu {
    href: string;
    rotulo: string;
    pronto: boolean; // false = tela ainda não construída (aparece como "em breve")
}

// As telas marcadas como pronto: false chegam nas próximas fases do roadmap
const ITENS: ItemMenu[] = [
    { href: "/calculadora", rotulo: "Calculadora", pronto: true },
    { href: "/vendas", rotulo: "Vendas", pronto: false },
    { href: "/producao", rotulo: "Produção", pronto: false },
    { href: "/clientes", rotulo: "Clientes", pronto: false },
    { href: "/lembretes", rotulo: "Lembretes", pronto: false },
    { href: "/configuracoes", rotulo: "Configurações", pronto: false },
];

interface SidebarProps {
    lojaNome: string;
    usuarioNome: string;
    papel: "dono" | "funcionario";
    diasRestantesTrial: number | null; // null = loja com assinatura ativa
}

export default function Sidebar({ lojaNome, usuarioNome, papel, diasRestantesTrial }: SidebarProps) {
    const pathname = usePathname();

    return (
        <aside className="flex shrink-0 flex-col gap-4 border-b border-ouro/30 bg-white p-4 md:min-h-screen md:w-64 md:border-b-0 md:border-r">
            <div>
                <p className="text-xl font-semibold tracking-tight text-grafite">
                    💎 Ouro<span className="text-ouro">Gest</span>
                </p>
                <p className="mt-1 truncate text-sm text-grafite/70" title={lojaNome}>
                    {lojaNome}
                </p>
            </div>

            {diasRestantesTrial !== null && (
                <p className="rounded-lg bg-ouro/10 px-3 py-2 text-xs font-medium text-ouro-escuro">
                    Teste grátis: {diasRestantesTrial}{" "}
                    {diasRestantesTrial === 1 ? "dia restante" : "dias restantes"}
                </p>
            )}

            <nav aria-label="Menu principal" className="flex gap-1 overflow-x-auto md:flex-col md:overflow-visible">
                {ITENS.map((item) => {
                    const ativo = pathname === item.href || pathname.startsWith(`${item.href}/`);

                    if (!item.pronto) {
                        return (
                            <span
                                key={item.href}
                                aria-disabled="true"
                                className="flex items-center justify-between whitespace-nowrap rounded-lg px-3 py-2 text-sm text-grafite/40"
                            >
                                {item.rotulo}
                                <span className="ml-2 rounded bg-grafite/5 px-1.5 py-0.5 text-[10px] uppercase">
                                    em breve
                                </span>
                            </span>
                        );
                    }

                    return (
                        <Link
                            key={item.href}
                            href={item.href}
                            aria-current={ativo ? "page" : undefined}
                            className={`whitespace-nowrap rounded-lg px-3 py-2 text-sm font-medium transition ${
                                ativo
                                    ? "bg-ouro text-white"
                                    : "text-grafite hover:bg-ouro/10"
                            }`}
                        >
                            {item.rotulo}
                        </Link>
                    );
                })}
            </nav>

            <div className="mt-auto flex items-center justify-between gap-2 border-t border-grafite/10 pt-4">
                <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-grafite">{usuarioNome}</p>
                    <p className="text-xs capitalize text-grafite/60">{papel}</p>
                </div>
                <LogoutButton />
            </div>
        </aside>
    );
}
