import mysql, { Pool, PoolConnection, RowDataPacket, ResultSetHeader } from "mysql2/promise"; // iMPORTANDO O PACOTE DO MYSQL

//AVISA O TS QUE PODEMOS GUARDAR O POOL NA MEMÓRIA LOCAL DO NODE
declare global {
    var mysqlPool: Pool | undefined;
}
// SE TIVER UM POOL NA MEMÓRIA, USA ELE SE NÃO (||) CRIA UM NOVO
const pool: Pool = global.mysqlPool || mysql.createPool({
    host: process.env.DB_HOST, // PROCESS.ENV = ARQUIVO ENV QUE POSSUI AS "INFORMAÕES" DO BD
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    timezone: 'Z',
    decimalNumbers: true, // DECIMAL PARA RETORNO DOS VALORES GUARDADOS, COMO VALORES E GRAMAS DA JOIA
});

//SE NÃO ESTIVER EM PRODUÇÃO, SALVA A MEMÓRIA NO POOL GLOBAL
if (process.env.NODE_ENV !== "production") {
    global.mysqlPool = pool;
}

export async function query<T = RowDataPacket[] >(
    sql: string,
    params: unknown[] = []    
): Promise<T> {
    const [rows] = await pool.execute(sql, params); // EVITA O ATAQUE SQL INJECTION, pois ENVIA SEPARADAMENTE A CONSULTA DOS PARAMETROS 
    return rows as T;
}

export async function execute(
    sql: string,
    params: unknown[] = [],
): Promise<ResultSetHeader>{
    const [result] = await pool.execute(sql, params);
    return result as ResultSetHeader;
}

export async function withTransaction<T>(
    callback: (connection: PoolConnection) => Promise<T>
):  Promise<T>{
    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();
        const result = await callback(connection);
        await connection.commit();
        return result;
    } catch (error) {
        await connection.rollback();
        throw error; // Repassa o erro de banco para o usuário final.
    } finally{
        connection.release();
    }
}

export default pool; // DISPONIBILIZA PARA OUTROS ARQUIVOS UTILIZAREM