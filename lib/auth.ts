import {getIronSession, IronSession, SessionOptions} from "iron-session";
import {cookies} from "next/headers";
import bcrypt from "bcryptjs";

// DADOS DO USUÁRIO LOGADO
export interface SessionUser {
    id: number;
    loja_id: number;
    nome: string;
    email: string;
    loja_nome: string;
    papel: "dono" | "funcionario";
    status_assinatura: "trial" | "ativa" | "vencida" | "bloqueada";
    trial_expira_em: string | null;
}

//Definindo que a sessão pode ter um usuário
export interface SessionData {
    user?: SessionUser;
}

// CONFIGURANDO IRONSESSION
export const sessionOptions: SessionOptions ={
    password: process.env.SESSION_SECRET as string,
    cookieName: "ourogest_session",
    cookieOptions:{
        httpOnly: true, // PROTEÇÃO CONTRA XSS
        secure: process.env.NODE_ENV === "production",
        sameSite: "lax", // PROTEÇÃO CONTRA ATAQUES DE FALSIFICAÇÃO DE REQUISIÇÃO
        maxAge: 60 * 120, // LOGIN DE DURAÇÃO DE 2 HORAS
        path: "/", // FAZ O DADOS DO USUÁRIO VALER PARA TODAS AS PÁGINAS
    },
};

//EMBARALHA A SENHA 2 ELEVADO NA 12
export async function hashPassword(password:string):Promise<string> {
    return bcrypt.hash(password, 12);
}

// COMPARA A SENHA DIGITADA NO LOGIN COM O HASH SALVO NO BD
export async function verifyPassword(
    password: string, 
    hash: string
): Promise<boolean> { // PROMETENDO RETORNAR COM UM TRUE OU FALSE APÓS VERIFICAR A SENHA
    return bcrypt.compare(password, hash);
}

//ABRE O IRONSESSION E LÊ OS COOKIES DA NAVEGAÇÃO
export async function getSession(): Promise<IronSession<SessionData>> {
    const cookieStore = await cookies();
    return getIronSession<SessionData>(cookieStore, sessionOptions);
}

// RETORNA OS DADOS DO USUÁRIO LOGADO
export async function getCurrentUser(): Promise<SessionUser | null> {
    const session = await getSession();
    return session.user || null;
}

//GARANTE QUE O USUÁRIO ESTEJA LOGADO ANTES DO ACESSO AOS DADOS DA LOJA
export async function requireAuth(): Promise<SessionUser> {
    const user = await getCurrentUser();
    if(!user){
        throw new Error("Não autorizado");
    }
    return user;
}
