import {NextRequest, NextResponse} from "next/server";
import {getIronSession} from "iron-session";
import {sessionOptions, SessionData} from "./lib/auth";

const protectedRoutes = [
    "/dashboard",
    "/clientes",
    "/vendas",
    "/calculadora",
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

    if (isProtectedRoute && !isAuthenticated) {
        return NextResponse.redirect(new URL("/login", request.url));
    }

    if (isAuthRoute && isAuthenticated) {
        return NextResponse.redirect(new URL("/dashboard", request.url));
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
    ],
};