"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import Campo from "@/app/components/Campo";

export default function CadastroForm() {
    const router = useRouter();
    const [lojaNome, setLojaNome] = useState("");
    const [nome, setNome] = useState("");
    const [email, setEmail] = useState("");
    const [senha, setSenha] = useState("");
    const [confirmarSenha, setConfirmarSenha] = useState("");
    const [erro, setErro] = useState("");
    const [carregando, setCarregando] = useState(false);

    async function enviar(e: FormEvent<HTMLFormElement>) {
        e.preventDefault();
        setErro("");

        if (senha !== confirmarSenha) {
            setErro("As senhas não conferem.");
            return;
        }

        setCarregando(true);
        try {
            const resposta = await fetch("/api/cadastro", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ loja_nome: lojaNome, nome, email, senha }),
            });
            const dados = await resposta.json();

            if (!resposta.ok) {
                setErro(dados.error || "Não foi possível criar a conta.");
                return;
            }

            // A API já abre a sessão ao criar a conta
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
                id="loja_nome"
                rotulo="Nome da joalheria"
                required
                minLength={2}
                value={lojaNome}
                onChange={(e) => setLojaNome(e.target.value)}
            />
            <Campo
                id="nome"
                rotulo="Seu nome"
                autoComplete="name"
                required
                minLength={4}
                value={nome}
                onChange={(e) => setNome(e.target.value)}
            />
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
                rotulo="Senha (mínimo 8 caracteres)"
                type="password"
                autoComplete="new-password"
                required
                minLength={8}
                value={senha}
                onChange={(e) => setSenha(e.target.value)}
            />
            <Campo
                id="confirmar_senha"
                rotulo="Confirmar senha"
                type="password"
                autoComplete="new-password"
                required
                minLength={8}
                value={confirmarSenha}
                onChange={(e) => setConfirmarSenha(e.target.value)}
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
                {carregando ? "Criando conta..." : "Começar teste grátis"}
            </button>
        </form>
    );
}
