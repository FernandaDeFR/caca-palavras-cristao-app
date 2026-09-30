import json
import random
import string
import re

# Tamanho padrão do grid (10x10)
GRID_SIZE = 10

# Vetores de direção (linha, coluna)
DIRECTIONS = {
    "nivel_1": [(0, 1), (1, 0)],  # Horizontal (direita), Vertical (baixo)
    "nivel_2": [(0, 1), (1, 0), (1, 1), (-1, 1)],  # Inclui Diagonais
    "nivel_3": [(0, 1), (1, 0), (1, 1), (-1, 1), (0, -1), (-1, 0), (-1, -1), (1, -1)],
    "nivel_4": [(0, 1), (1, 0), (1, 1), (-1, 1), (0, -1), (-1, 0), (-1, -1), (1, -1)]
}

DIR_NAMES = {
    (0, 1): "horizontal",
    (1, 0): "vertical",
    (1, 1): "diagonal_descendente",
    (-1, 1): "diagonal_ascendente",
    (0, -1): "horizontal_invertida",
    (-1, 0): "vertical_invertida",
    (-1, -1): "diagonal_descendente_invertida",
    (1, -1): "diagonal_ascendente_invertida"
}

def criar_grid_vazio(size=GRID_SIZE):
    return [["" for _ in range(size)] for _ in range(size)]

def pode_posicionar(grid, palavra, r, c, dr, dc, size=GRID_SIZE):
    len_p = len(palavra)
    end_r = r + (len_p - 1) * dr
    end_c = c + (len_p - 1) * dc

    if not (0 <= end_r < size and 0 <= end_c < size):
        return False

    for i in range(len_p):
        curr_r = r + i * dr
        curr_c = c + i * dc
        celula_atual = grid[curr_r][curr_c]
        if celula_atual != "" and celula_atual != palavra[i]:
            return False

    return True

def posicionar_palavra(grid, palavra, r, c, dr, dc):
    for i, char in enumerate(palavra):
        grid[r + i * dr][c + i * dc] = char

def preencher_lixo(grid, size=GRID_SIZE):
    letras = string.ascii_uppercase
    for r in range(size):
        for c in range(size):
            if grid[r][c] == "":
                grid[r][c] = random.choice(letras)

def orientacoes_sao_validas(solucoes, total_palavras, dificuldade):
    contagem = {}
    for s in solucoes:
        ori = s["orientacao"]
        contagem[ori] = contagem.get(ori, 0) + 1

    if dificuldade == "nivel_1":
        return abs(contagem.get("horizontal", 0) - contagem.get("vertical", 0)) <= 1

    if dificuldade == "nivel_2" and total_palavras >= 3:
        if not any(s["orientacao"].startswith("diagonal") for s in solucoes):
            return False
    if dificuldade in ("nivel_3", "nivel_4") and total_palavras >= 3:
        if not any(s["orientacao"].startswith("diagonal") and
                   s["orientacao"].endswith("invertida") for s in solucoes):
            return False
        if not any(s["orientacao"] in ("horizontal_invertida", "vertical_invertida")
                   for s in solucoes):
            return False

    # Nos outros níveis, exige ao menos duas orientações.
    if total_palavras >= 4 and len(contagem) < 2:
        return False

    return True

def tentar_gerar_etapa(etapa_input, max_tentativas=1000):
    dificuldade = etapa_input.get("dificuldade", "nivel_1")
    if dificuldade not in DIRECTIONS:
        raise ValueError(f"Dificuldade desconhecida: {dificuldade}")
    direcoes_permitidas = DIRECTIONS[dificuldade]
    palavras_original = etapa_input.get("palavras", [])

    for p in palavras_original:
        if len(p) > GRID_SIZE:
            print(f"⚠️ AVISO: A palavra '{p}' tem {len(p)} letras e excede o limite do grid ({GRID_SIZE}x{GRID_SIZE}).")

    palavras_ordenadas = sorted(palavras_original, key=len, reverse=True)

    for _ in range(max_tentativas):
        grid = criar_grid_vazio()
        solucoes = []
        sucesso = True

        for palavra in palavras_ordenadas:
            palavra_formatada = palavra.upper()
            len_p = len(palavra_formatada)

            posicionada = False
            contagem_direcoes = {d: 0 for d in direcoes_permitidas}
            for solucao in solucoes:
                for direcao in direcoes_permitidas:
                    if DIR_NAMES[direcao] == solucao["orientacao"]:
                        contagem_direcoes[direcao] += 1

            direcoes_ordenadas = direcoes_permitidas.copy()
            random.shuffle(direcoes_ordenadas)
            direcoes_ordenadas.sort(key=lambda d: contagem_direcoes[d])

            for dr, dc in direcoes_ordenadas:
                tentativas_palavra = list(range(GRID_SIZE * GRID_SIZE))
                random.shuffle(tentativas_palavra)
                for pos in tentativas_palavra:
                    r = pos // GRID_SIZE
                    c = pos % GRID_SIZE
                    if pode_posicionar(grid, palavra_formatada, r, c, dr, dc):
                        posicionar_palavra(grid, palavra_formatada, r, c, dr, dc)
                        
                        end_r = r + (len_p - 1) * dr
                        end_c = c + (len_p - 1) * dc
                        
                        solucoes.append({
                            "palavra": palavra_formatada,
                            "inicio": [r, c],
                            "fim": [end_r, end_c],
                            "orientacao": DIR_NAMES.get((dr, dc), "horizontal")
                        })
                        posicionada = True
                        break
                if posicionada:
                    break

            if not posicionada:
                sucesso = False
                break

        # Valida se as palavras não ficaram todas na mesma direção
        if sucesso and orientacoes_sao_validas(solucoes, len(palavras_original), dificuldade):
            preencher_lixo(grid)
            
            etapa_output = {}
            for k, v in etapa_input.items():
                if k != "palavras":
                    etapa_output[k] = v
            
            grid_formatado = ["".join(linha) for linha in grid]

            etapa_output["qtd_palavras"] = len(palavras_original)
            etapa_output["grid"] = grid_formatado
            etapa_output["solucao"] = solucoes
            return etapa_output

    raise Exception(f"Não foi possível gerar o grid para a etapa {etapa_input.get('etapa')}. Verifique se o tamanho das palavras é compatível.")

def processar_elemento(elemento):
    if isinstance(elemento, dict):
        novo_dict = {}
        for chave, valor in elemento.items():
            if chave == "etapas" and isinstance(valor, list):
                novo_dict["etapas"] = [tentar_gerar_etapa(et) for et in valor]
            else:
                novo_dict[chave] = processar_elemento(valor)
        return novo_dict
    elif isinstance(elemento, list):
        return [processar_elemento(item) for item in elemento]
    else:
        return elemento

def formatar_json_compacto(json_str):
    json_str = re.sub(r'\[\s*(\d+),\s*(\d+)\s*\]', r'[\1, \2]', json_str)
    
    def compactar_solucao_obj(match):
        conteudo = match.group(0)
        conteudo_limpo = re.sub(r'\s*\n\s*', ' ', conteudo)
        conteudo_limpo = re.sub(r'\s+', ' ', conteudo_limpo)
        return conteudo_limpo

    json_str = re.sub(r'\{\s*"palavra":.*?"orientacao":\s*"[^\"]*"\s*\}', compactar_solucao_obj, json_str, flags=re.DOTALL)
    return json_str

def processar_insumo(caminho_entrada="insumo.json", caminho_saida="caca_palavras.json"):
    with open(caminho_entrada, "r", encoding="utf-8") as f:
        dados_insumo = json.load(f)

    resultado = processar_elemento(dados_insumo)

    json_bruto = json.dumps(resultado, ensure_ascii=False, indent=2)
    json_formatado = formatar_json_compacto(json_bruto)

    with open(caminho_saida, "w", encoding="utf-8") as f:
        f.write(json_formatado)

    print(f"✅ Arquivo '{caminho_saida}' gerado com sucesso!")

if __name__ == "__main__":
    processar_insumo("insumo.json", "caca_palavras.json")
