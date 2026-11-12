"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function LogoutButton({ className = "" }: { className?: string }) {
    const router = useRouter();
    const [saindo, setSaindo] = useState(false);

    async function sair() {
        setSaindo(true);
        try {
            await fetch("/api/logout", { method: "POST" });
        } finally {
            router.push("/login");
            router.refresh();
        }
    }

    return (
        <button
            type="button"
            onClick={sair}
            disabled={saindo}
            className={`rounded-lg border border-grafite/20 px-4 py-2 text-sm font-medium text-grafite transition hover:bg-grafite/5 disabled:opacity-60 ${className}`}
        >
            {saindo ? "Saindo..." : "Sair"}
        </button>
    );
}
