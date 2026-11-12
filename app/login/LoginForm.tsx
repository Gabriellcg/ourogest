"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import Campo from "@/app/components/Campo";

export default function LoginForm() {
    const router = useRouter();
    const [email, setEmail] = useState("");
    const [senha, setSenha] = useState("");
    const [erro, setErro] = useState("");
    const [carregando, setCarregando] = useState(false);

    async function enviar(e: FormEvent<HTMLFormElement>) {
        e.preventDefault();
        setErro("");
        setCarregando(true);

        try {
            const resposta = await fetch("/api/login", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ email, senha }),
            });
            const dados = await resposta.json();

            if (!resposta.ok) {
                setErro(dados.error || "Não foi possível entrar.");
                return;
            }

            // O middleware leva para /assinatura se o teste grátis já tiver vencido
            router.push("/calculadora");
            router.refresh();
        } catch {
            setErro("Não foi possível conectar ao servidor. Tente novamente.");
        } finally {
            setCarregando(false);
        }
    }

    return (
        <form onSubmit={enviar} className="space-y-4">
            <Campo
                id="email"
                rotulo="E-mail"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
            />
            <Campo
                id="senha"
                rotulo="Senha"
                type="password"
                autoComplete="current-password"
                required
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
            />

            {erro && (
                <p role="alert" className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
                    {erro}
                </p>
            )}

            <button
                type="submit"
                disabled={carregando}
                className="w-full rounded-lg bg-ouro px-4 py-2.5 font-medium text-white transition hover:bg-ouro-escuro disabled:opacity-60"
            >
                {carregando ? "Entrando..." : "Entrar"}
            </button>
        </form>
    );
}
