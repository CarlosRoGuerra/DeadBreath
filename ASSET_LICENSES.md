# Registro de Licenças de Assets — DEAD BREATH

| Campo | Valor |
|---|---|
| Criado | 2026-11-20 (F1-014) |
| Responsável | Art & Environment; conferido pelo Technical Reviewer em toda revisão |

## Regras

1. **Nenhum asset externo entra no repositório sem uma linha nesta tabela**: modelo, textura, material, som, música, fonte, HDRI ou animação.
2. A decisão **D-06** foi aprovada pelo usuário em 2026-11-20. Assets **CC0** entram sem aprovação extra (fontes preferidas: Poly Haven, ambientCG, Quaternius, Kenney). Qualquer outra licença (CC-BY, royalty-free etc.) exige aprovação do Project Director e do usuário, registrada na coluna "Aprovado por".
3. Assets criados no projeto não precisam de linha; o histórico do git é a origem.
4. Guarde a URL da página do asset (não do download direto) e a data em que a licença foi conferida.
5. Baixe somente da página oficial da fonte. Só arquivos de dados (texturas, modelos, sons, HDRIs); nada executável.
6. Assets externos ficam em `game/content/<tipo>/external/<fonte>/` para que a origem seja óbvia no caminho.

## Assets externos

| Asset (caminho no repo) | Fonte | Autor | Licença | URL | Conferido em | Aprovado por |
|---|---|---|---|---|---|---|
| `game/content/textures/external/ambientcg/WoodFloor041/` (mapas 1K JPG: color, normal GL, roughness, AO); material `game/content/materials/mat_floor_wood.tres` | ambientCG (https://ambientcg.com) | ambientCG (a página não informa autor individual) | CC0 (declarada na página: "All assets are released under the Creative Commons CC0 license") | https://ambientcg.com/a/WoodFloor041 | 2026-11-20 | D-06 |
| `game/content/textures/external/ambientcg/Carpet016/` (mapas 1K JPG: color, normal GL, roughness, AO); material `game/content/materials/mat_floor_carpet.tres` | ambientCG (https://ambientcg.com) | ambientCG (a página não informa autor individual) | CC0 (declarada na página) | https://ambientcg.com/a/Carpet016 | 2026-11-20 | D-06 |
| `game/content/textures/external/ambientcg/Tiles142/` (mapas 1K JPG: color, normal GL, roughness); material `game/content/materials/mat_floor_tile.tres` | ambientCG (https://ambientcg.com) | ambientCG (a página não informa autor individual) | CC0 (declarada na página) | https://ambientcg.com/a/Tiles142 | 2026-11-20 | D-06 |
| `game/content/textures/external/ambientcg/Concrete036/` (mapas 1K JPG: color, normal GL, roughness); material `game/content/materials/mat_floor_concrete.tres` | ambientCG (https://ambientcg.com) | ambientCG (a página não informa autor individual) | CC0 (declarada na página) | https://ambientcg.com/a/Concrete036 | 2026-11-20 | D-06 |
| `game/content/textures/external/ambientcg/Plaster007/` (mapas 1K JPG: color, normal GL, roughness, AO); material `game/content/materials/mat_wall_plaster.tres` | ambientCG (https://ambientcg.com) | ambientCG (a página não informa autor individual) | CC0 (declarada na página) | https://ambientcg.com/a/Plaster007 | 2026-11-20 | D-06 |

Assets externos atuais: cinco materiais CC0 do ambientCG (F1-D03), 1K JPG, só os mapas usados. Os arquivos ZIP baixados não foram versionados, e os arquivos de exportação incluídos nos ZIPs (.blend, .usdc, .mtlx) não foram copiados.
