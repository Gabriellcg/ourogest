// Regras de acesso do teste grátis e da assinatura (mesma lógica do middleware.ts e da view lojas_acesso)

export type StatusAssinatura = "trial" | "ativa" | "vencida" | "bloqueada";

const MS_POR_DIA = 86_400_000;

// Dias que faltam do teste grátis (arredondado para cima, mínimo 0).
// Retorna null quando a loja não está em teste (assinatura ativa, vencida ou bloqueada).
export function diasRestantesTrial(
    status: StatusAssinatura,
    trialExpiraEm: string | null,
    agora: Date = new Date()
): number | null {
    if (status !== "trial" || !trialExpiraEm) return null;
    const msRestantes = new Date(trialExpiraEm).getTime() - agora.getTime();
    return Math.max(0, Math.ceil(msRestantes / MS_POR_DIA));
}

// true = as telas operacionais ficam bloqueadas e o usuário vai para /assinatura
export function acessoBloqueado(
    status: StatusAssinatura,
    trialExpiraEm: string | null,
    agora: Date = new Date()
): boolean {
    if (status === "vencida" || status === "bloqueada") return true;
    if (status === "trial") {
        return !trialExpiraEm || agora > new Date(trialExpiraEm);
    }
    return false;
}
