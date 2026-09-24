# BroforceAndroid

Port não oficial do **Broforce** (PC/Steam) para Android, jogado com **gamepad**.

> **Este repositório não contém nenhum arquivo do jogo.** Nada de assets, DLLs ou código decompilado. Ele guarda só documentação, scripts e patches. Para usar, você precisa ter **a sua própria cópia do Broforce na Steam**: o pipeline pega os arquivos da sua instalação local e gera um APK para uso pessoal. Não distribua APKs gerados.
>
> Broforce é propriedade da Free Lives e da Devolver Digital. Este projeto não tem nenhuma ligação com elas.

*English: unofficial, gamepad-only Android port of Broforce. No game files are included; you need your own Steam copy. Personal use only.*

## Escopo

- **Só gamepad**: controle físico, com cabo (USB-C) ou Bluetooth. Não vai ter controle na tela.
- **Android ARMv7 (Mono)**: o jogo é Unity 2017.4 com backend Mono, que só gera 32 bits. O celular precisa aceitar `armeabi-v7a`.
- Sem Steam: conquistas, estatísticas e multiplayer online ficam desativados.

Para saber se o seu celular é compatível:

```sh
adb shell getprop ro.product.cpu.abilist
# precisa listar armeabi-v7a
```

## Como funciona

1. **Exportar**: o [AssetRipper](https://github.com/AssetRipper/AssetRipper) transforma a sua instalação do Broforce em um projeto Unity.
2. **Patch**: os scripts deste repo removem o que não existe no Android (Steamworks, SDKs de console, Windows Forms), ajustam os saves, os shaders e a entrada do controle.
3. **Build**: o Unity 2017.4.7f1 gera o APK.

## Status

Em andamento. O roteiro está nas [issues](../../issues) e nos [milestones](../../milestones), divididos em fases:

| Fase | Objetivo | Portão |
|---|---|---|
| 0 | Reconhecimento | Versão do Unity, plugins e ABI do celular conhecidos ✅ |
| 1 | Exportar com AssetRipper | Projeto abre no Editor sem erros de compilação |
| 2 | Rodar no Editor | Uma missão inteira jogável no PC |
| 3 | Primeiro build Android | O jogo abre no celular e chega ao menu |
| 4 | Gamepad | Uma missão inteira no celular com controle |
| 5 | Desempenho e polimento | Todos os mundos jogáveis com FPS estável |

Os detalhes técnicos estão em [docs/](docs/).

## Requisitos (desenvolvimento)

- Broforce instalado pela Steam (Windows)
- Unity 2017.4.7f1 com o módulo Android Build Support
- JDK 8 (o Unity 2017.4 não funciona com JDK 11+)
- Android SDK + `adb`
- AssetRipper 2.x

## Contribuindo

Issues e PRs são bem-vindos. Regra de ouro: **nunca faça commit de arquivos do jogo** nem de código decompilado dele. Mudanças no código do jogo entram como patch ou script aplicado sobre a exportação local.

Parte do planejamento e do código foi feita com ajuda de ferramentas de IA.

## Licença

[MIT](LICENSE), válida só para o conteúdo original deste repositório.
