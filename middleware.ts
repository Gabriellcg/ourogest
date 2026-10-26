import {NextRequest, NextResponse} from "next/server";
import {getIronSession} from "iron-session";
import {sessionOptions, SessionData} from "./lib/auth";

const protectedRoutes = [
    "/dashboard",
    "/calculadora",
    "/producao",
    "/lembretes",
    "/clientes",
    "/vendas",
    "/configuracoes",
];

const authRoutes = ["/login", "/cadastro"];

export async function middleware(request: NextRequest){
    const response = NextResponse.next();
    const session = await getIronSession<SessionData>(
        request,
        response,
        sessionOptions
    );

    const {pathname} = request.nextUrl;
    const isAuthenticated = Boolean(session.user);

    const isProtectedRoute = protectedRoutes.some((route) => 
        pathname.startsWith(route));
    
    const isAuthRoute = authRoutes.some((route) => 
        pathname.startsWith(route));

    const isAssinaturaRoute = pathname.startsWith("/assinatura");

    if ((isProtectedRoute || isAssinaturaRoute) && !isAuthenticated) {
        return NextResponse.redirect(new URL("/login", request.url));
    }

    if (isAuthRoute && isAuthenticated) {
        return NextResponse.redirect(new URL("/calculadora", request.url));
    }

    if (isAuthenticated && session.user) {
        const {status_assinatura, trial_expira_em} = session.user;
        const agora = new Date();
        const dataExpiracao = trial_expira_em ? new Date(trial_expira_em): null;

        const trialExpirado =
            status_assinatura === "trial" && (!dataExpiracao || agora > dataExpiracao);

        const assinaturaInativa =
            status_assinatura === "vencida" || status_assinatura === "bloqueada";

        const bloqueadoPorAssinatura = trialExpirado || assinaturaInativa;

        if (isProtectedRoute && bloqueadoPorAssinatura) {
            return NextResponse.redirect(new URL("/assinatura", request.url));
        }

        if (isAssinaturaRoute && !bloqueadoPorAssinatura) {
            return NextResponse.redirect(new URL("/calculadora", request.url));
        }
        
    }

    return response;
}

export const config = {
    matcher: [
        "/dashboard/:path*",
        "/clientes/:path*",
        "/vendas/:path*",
        "/calculadora/:path*",
        "/configuracoes/:path*",
        "/login",
        "/cadastro", 
        "/producao/:path*",
        "/lembretes/:path*",
        "/assinatura/:path*",
    ],
};