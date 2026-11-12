import type { InputHTMLAttributes } from "react";

interface CampoProps extends InputHTMLAttributes<HTMLInputElement> {
    rotulo: string;
}

// Campo de formulário com rótulo, no padrão visual do sistema
export default function Campo({ rotulo, id, ...props }: CampoProps) {
    return (
        <div>
            <label htmlFor={id} className="mb-1 block text-sm font-medium text-grafite">
                {rotulo}
            </label>
            <input
                id={id}
                {...props}
                className="w-full rounded-lg border border-grafite/20 bg-white px-3 py-2 text-grafite outline-none transition focus:border-ouro focus:ring-2 focus:ring-ouro/30"
            />
        </div>
    );
}
