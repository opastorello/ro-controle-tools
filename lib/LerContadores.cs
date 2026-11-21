using System;
using System.Collections.Generic;
using System.Data.SQLite;
using System.Net;
using SnmpSharpNet;

class Program {
    static string dbPath = @"C:\RO\LeituraOID\tarifador.db";
    static string community = "public";
    static int timeout = 300;
    static int retries = 2;

    static void Main(string[] args) {
        Console.WriteLine("=== Leitura SNMP de Contadores ===");
        Console.WriteLine();

        // Aceitar argumentos: LerContadores.exe [dbPath] [community]
        if (args.Length >= 1 && !string.IsNullOrEmpty(args[0])) {
            dbPath = args[0];
            Console.WriteLine("Banco: " + dbPath);
        }
        if (args.Length >= 2 && !string.IsNullOrEmpty(args[1])) {
            community = args[1];
        }

        try {
            // Buscar equipamentos ativos
            var equipamentos = GetEquipamentosAtivos();
            Console.WriteLine("Equipamentos encontrados: " + equipamentos.Count);

            if (equipamentos.Count == 0) {
                Console.WriteLine("Nenhum equipamento encontrado.");
                return;
            }

            int totalLeituras = 0;
            int erros = 0;
            int offline = 0;

            foreach (var equip in equipamentos) {
                Console.WriteLine();
                Console.WriteLine("Lendo: " + equip.NrSerie + " (" + equip.IP + ")");

                // Verificar se IP esta vivo
                if (!PingHost(equip.IP)) {
                    Console.WriteLine("  [OFFLINE] IP nao responde");
                    offline++;
                    continue;
                }

                Console.WriteLine("  [ONLINE]");

                // Buscar OIDs do equipamento
                var oids = GetOIDsEquipamento(equip.IP, equip.Mac, equip.NrSerie);
                Console.WriteLine("  OIDs a ler: " + oids.Count);

                foreach (var oid in oids) {
                    try {
                        string valor = LerSNMP(equip.IP, oid.OID);
                        if (valor != null && valor != "Nulo" && valor.Length > 0) {
                            // Adicionar prefixo Hexa se houver
                            if (!string.IsNullOrEmpty(oid.Hexa)) {
                                valor = oid.Hexa + ":" + valor;
                            }

                            // Inserir leitura no banco
                            InserirLeitura(equip.IdEquipamento, oid.IdOid, valor);
                            totalLeituras++;

                            // Mostrar apenas os primeiros 50 chars do valor
                            string valorDisplay = valor.Length > 50 ? valor.Substring(0, 50) + "..." : valor;
                            Console.WriteLine("    OK: " + valorDisplay);
                        }
                    } catch (Exception ex) {
                        erros++;
                        Console.WriteLine("    ERRO: " + ex.Message);
                    }
                }
            }

            Console.WriteLine();
            Console.WriteLine("==========================================");
            Console.WriteLine("  CONCLUIDO!");
            Console.WriteLine("  Leituras inseridas: " + totalLeituras);
            Console.WriteLine("  Equipamentos offline: " + offline);
            Console.WriteLine("  Erros: " + erros);
            Console.WriteLine("==========================================");

            // Atualizar data de leitura
            if (totalLeituras > 0) {
                AtualizarDataLeitura();
            }

        } catch (Exception ex) {
            Console.WriteLine("ERRO GERAL: " + ex.Message);
        }
    }

    static List<Equipamento> GetEquipamentosAtivos() {
        var lista = new List<Equipamento>();
        using (var conn = new SQLiteConnection("Data Source=" + dbPath + ";Version=3;")) {
            conn.Open();
            var cmd = conn.CreateCommand();
            cmd.CommandText = @"SELECT id, numero_serie, ip_atual, id_modelo, mac_address
                                FROM equipamentos
                                WHERE contrato = 'SIM'";
            var reader = cmd.ExecuteReader();
            while (reader.Read()) {
                lista.Add(new Equipamento {
                    IdEquipamento = reader["id"].ToString(),
                    NrSerie = reader["numero_serie"].ToString(),
                    IP = reader["ip_atual"].ToString(),
                    IdModelo = reader["id_modelo"].ToString(),
                    Mac = reader["mac_address"].ToString()
                });
            }
        }
        return lista;
    }

    static List<OidInfo> GetOIDsEquipamento(string ip, string mac, string nrSerie) {
        var lista = new List<OidInfo>();
        using (var conn = new SQLiteConnection("Data Source=" + dbPath + ";Version=3;")) {
            conn.Open();
            var cmd = conn.CreateCommand();
            // Query original do programa - busca OIDs por duas vias (grupos e direto)
            cmd.CommandText = @"
                SELECT Id, numero_serie, OID, hexa, id_oid, contrato FROM (
                    SELECT Id, numero_serie, mac_address, OID as Oid, ip_atual as Ip, HEXA, id_oid, contrato FROM (
                        SELECT A.id as ID, A.numero_serie as numero_serie, E.OID as OID, A.mac_address, A.ip_atual, E.HEXA, E.Id as id_oid, A.contrato
                        FROM equipamentos A
                        LEFT JOIN modelos B ON (A.id_modelo = B.id)
                        LEFT JOIN modelos_oids_grupos C ON (A.id_modelo = C.id_modelo)
                        LEFT JOIN oids_grupos_oids D ON (C.ID_GRUPO = D.ID_GRUPO)
                        LEFT JOIN oids E ON (D.ID_OID = E.ID)
                        WHERE oid <> ''
                        UNION
                        SELECT A.id as ID, A.numero_serie as numero_serie, D.OID as OID, A.mac_address, A.ip_atual, D.HEXA, D.id as id_oid, A.contrato
                        FROM equipamentos A
                        LEFT JOIN modelos B ON (A.id_modelo = B.id)
                        LEFT JOIN modelos_oids C ON (B.id = C.id_modelo)
                        LEFT JOIN oids D ON (C.Id_Oid = D.id)
                        WHERE oid <> ''
                    ) tab3
                ) tab4
                WHERE mac_address = @mac AND IP = @ip AND numero_serie = @nrSerie AND contrato = 'SIM'";
            cmd.Parameters.AddWithValue("@mac", mac);
            cmd.Parameters.AddWithValue("@ip", ip);
            cmd.Parameters.AddWithValue("@nrSerie", nrSerie);
            var reader = cmd.ExecuteReader();
            while (reader.Read()) {
                string hexa = "";
                if (reader["hexa"] != DBNull.Value && reader["hexa"] != null) {
                    hexa = reader["hexa"].ToString();
                }
                string oid = reader["OID"].ToString();
                // Evitar duplicados
                if (!string.IsNullOrEmpty(oid) && lista.Find(x => x.OID == oid) == null) {
                    lista.Add(new OidInfo {
                        IdOid = reader["id_oid"].ToString(),
                        OID = oid,
                        Descricao = "",
                        Hexa = hexa
                    });
                }
            }
        }
        return lista;
    }

    static string LerSNMP(string ip, string oid) {
        try {
            Pdu pdu = new Pdu(PduType.Get);
            pdu.VbList.Add(oid);

            UdpTarget target = new UdpTarget((IPAddress)new IpAddress(ip), 161, timeout, retries);
            AgentParameters param = new AgentParameters(new OctetString(community));
            param.Version = SnmpVersion.Ver1;

            SnmpPacket result = target.Request(pdu, param);
            target.Close();

            if (result != null && result.Pdu.ErrorStatus == 0) {
                return result.Pdu.VbList[0].Value.ToString();
            }
        } catch { }
        return "Nulo";
    }

    static void InserirLeitura(string idEquipamento, string idOid, string valor) {
        using (var conn = new SQLiteConnection("Data Source=" + dbPath + ";Version=3;")) {
            conn.Open();
            var cmd = conn.CreateCommand();
            cmd.CommandText = @"INSERT INTO leitura_log (id, id_equipamento, id_oid, valor, data_leitura)
                                VALUES (@id, @idEquip, @idOid, @valor, @data)";
            cmd.Parameters.AddWithValue("@id", Guid.NewGuid().ToString());
            cmd.Parameters.AddWithValue("@idEquip", idEquipamento);
            cmd.Parameters.AddWithValue("@idOid", idOid);
            cmd.Parameters.AddWithValue("@valor", valor);
            cmd.Parameters.AddWithValue("@data", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fffffff"));
            cmd.ExecuteNonQuery();
        }
    }

    static void AtualizarDataLeitura() {
        using (var conn = new SQLiteConnection("Data Source=" + dbPath + ";Version=3;")) {
            conn.Open();
            var cmd = conn.CreateCommand();
            cmd.CommandText = "UPDATE clientes SET data_ultima_leitura = @data";
            cmd.Parameters.AddWithValue("@data", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fffffff"));
            cmd.ExecuteNonQuery();
        }
        Console.WriteLine("Data ultima leitura atualizada.");
    }

    static bool PingHost(string ip) {
        try {
            var ping = new System.Net.NetworkInformation.Ping();
            var reply = ping.Send(ip, 1000);
            return reply.Status == System.Net.NetworkInformation.IPStatus.Success;
        } catch {
            return false;
        }
    }
}

class Equipamento {
    public string IdEquipamento { get; set; }
    public string NrSerie { get; set; }
    public string IP { get; set; }
    public string IdModelo { get; set; }
    public string Mac { get; set; }
}

class OidInfo {
    public string IdOid { get; set; }
    public string OID { get; set; }
    public string Descricao { get; set; }
    public string Hexa { get; set; }
}
