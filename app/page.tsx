import { redirect } from "next/navigation";

// A página inicial só encaminha para o login (quem já está logado é levado à calculadora pelo middleware)
export default function Home() {
  redirect("/login");
}
