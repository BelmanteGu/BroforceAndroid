# Fase 0: Reconhecimento

Levantamento feito na build Steam `12964083` do Broforce (Windows x64).

## Engine

| Item | Valor | Como verificar |
|---|---|---|
| Versão do Unity | **2017.4.7f1** | Propriedades de `UnityPlayer.dll` (FileVersion `2017.4.7.x`) |
| Backend de script | **Mono** | Existe `Broforce_beta_Data/Managed/Assembly-CSharp.dll`; não existem `GameAssembly.dll` nem `il2cpp_data/` |
| Módulos do Unity | Separados (`UnityEngine.CoreModule.dll` etc.) | Pasta `Managed/` |

Consequência: no Android, o Unity 2017.4 com Mono gera só **ARMv7 (32 bits)**. ARM64 exigiria IL2CPP, o que na prática significa migrar o projeto para o Unity 2018.2 ou mais novo. Por enquanto o alvo é ARMv7.

## Assemblies gerenciados relevantes

| Assembly | O que é | Plano para o Android |
|---|---|---|
| `Assembly-CSharp.dll`, `Assembly-CSharp-firstpass.dll` | Código do jogo | Base do port |
| `Assembly-UnityScript*.dll`, `Boo.Lang.dll` | Scripts antigos em UnityScript | Manter como DLL |
| `Rewired_Core.dll`, `Rewired_Windows_Lib.dll` | Entrada (Rewired) | A lib de Windows não roda no Android. Investigar o fallback para a entrada do Unity. Maior risco da Fase 4 |
| `System.Windows.Forms.dll`, `System.Drawing.dll`, `CommonForms.dll` | UI de Windows | Remover ou criar stubs |
| `PowerInspector.Runtime.dll`, `Sisus.*` | Inspector em runtime e serialização Odin | Verificar se o jogo depende disso em runtime |
| `Gif.Components.dll`, `GifComponents.dll` | Gravação de GIF | Desativar |
| `AlienFXManagedWrapper3.5.dll` | Luzes de teclado Alienware | Desativar |
| `*Import.dll` (ConsoleUtils, DataPlatform, Friends, GameDVR, Gamepad, Marketplace, Multiplayer, SmartGlass, Storage, StreamingInstall, TextSystems, Users, XIM, XboxOneCommon) | Wrappers do SDK de Xbox | Remover ou proteger com checagem de plataforma |
| `SonyNP.dll`, `SonyPS4*.dll` | SDK de PS4 | Remover |
| `UnityEngine.Networking.dll` | UNET | Avaliar se o multiplayer local depende disso |

## Plugins nativos (`Broforce_beta_Data/Plugins`)

Todos são **Windows x64** e nenhum funciona no Android:

- `CSteamworks.dll`, `steam_api64.dll`: Steamworks.NET → criar stub
- `NatCorder.dll`: gravação de vídeo → desativar
- `NintendoSDKPlugin.dll`, `nn_piaPlugin.dll`: Switch → remover
- `ConsoleUtils.dll`, `DataPlatform.dll`, `Friends.dll`, `GameDVR.dll`, `Gamepad.dll`, `LiveServices.dll`, `Marketplace.dll`, `Multiplayer.dll`, `SmartGlass.dll`, `Storage.dll`, `StreamingInstall.dll`, `TextSystems.dll`, `Users.dll`, `XIM.dll`, `UnityPluginLog.dll`: Xbox → remover

## Dispositivo de referência

| Item | Valor |
|---|---|
| Aparelho | Samsung Galaxy S23 (SM-S911B, Snapdragon 8 Gen 2 / SM8550) |
| Android | 16 |
| `ro.product.cpu.abilist` | `arm64-v8a,armeabi-v7a,armeabi` ✅ aceita ARMv7 |
| Controle | GameSir com cabo USB-C |

Como a porta USB fica ocupada pelo controle, o debug tem que ser feito por **adb sem fio** (`adb pair` / `adb connect`).

## Observações sobre o AssetRipper (2.0.0)

- Modos de script: `Decompiled`, `Hybrid`, `DllExportWithRenaming`, `DllExportWithoutRenaming`.
- A decompilação de shaders é recurso **pago**. Na versão gratuita os shaders saem como placeholders (`Dummy`). Isso não chega a ser um problema: os shaders do PC são bytecode DirectX e teriam que ser reescritos para GLES de qualquer forma.
- Pode rodar sem interface: `AssetRipper.GUI.Free.exe --headless --port 5123` expõe uma API HTTP (`/LoadFolder`, `/Settings/Update`, `/Export/UnityProject`), o que permite automatizar a exportação.
