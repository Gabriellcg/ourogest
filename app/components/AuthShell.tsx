import type { ReactNode } from "react";

interface AuthShellProps {
    titulo: string;
    subtitulo?: string;
    children: ReactNode;
}

// Moldura visual das telas de login, cadastro e assinatura
export default function AuthShell({ titulo, subtitulo, children }: AuthShellProps) {
    return (
        <main className="flex min-h-screen items-center justify-center bg-marfim px-4 py-10">
            <div className="w-full max-w-md">
                <div className="mb-6 text-center">
                    <p className="text-3xl font-semibold tracking-tight text-grafite">
                        💎 Ouro<span className="text-ouro">Gest</span>
                    </p>
                </div>

                <div className="rounded-2xl border border-ouro/30 bg-white p-8 shadow-sm">
                    <h1 className="text-xl font-semibold text-grafite">{titulo}</h1>
                    {subtitulo && <p className="mt-1 text-sm text-grafite/70">{subtitulo}</p>}
                    <div className="mt-6">{children}</div>
                </div>
            </div>
        </main>
    );
}
