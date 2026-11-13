import { describe, expect, it } from "vitest";
import { acessoBloqueado, diasRestantesTrial } from "../assinatura";

const agora = new Date("2026-11-12T12:00:00Z");
const emDias = (d: number) => new Date(agora.getTime() + d * 86_400_000).toISOString();

describe("diasRestantesTrial", () => {
    it("conta os dias que faltam, arredondando para cima", () => {
        expect(diasRestantesTrial("trial", emDias(7), agora)).toBe(7);
        expect(diasRestantesTrial("trial", emDias(0.2), agora)).toBe(1);
    });
    it("nunca fica negativo", () => {
        expect(diasRestantesTrial("trial", emDias(-3), agora)).toBe(0);
    });
    it("retorna null fora do teste grátis", () => {
        expect(diasRestantesTrial("ativa", null, agora)).toBeNull();
        expect(diasRestantesTrial("vencida", emDias(5), agora)).toBeNull();
    });
});

describe("acessoBloqueado", () => {
    it("libera trial dentro do prazo e assinatura ativa", () => {
        expect(acessoBloqueado("trial", emDias(1), agora)).toBe(false);
        expect(acessoBloqueado("ativa", null, agora)).toBe(false);
    });
    it("bloqueia trial vencido, trial sem data, vencida e bloqueada", () => {
        expect(acessoBloqueado("trial", emDias(-1), agora)).toBe(true);
        expect(acessoBloqueado("trial", null, agora)).toBe(true);
        expect(acessoBloqueado("vencida", null, agora)).toBe(true);
        expect(acessoBloqueado("bloqueada", null, agora)).toBe(true);
    });
});
