# arch-repo

Repositório pacman com os meus apps para Arch Linux, compilado pelo GitHub
Actions e publicado na release [`x86_64`](../../releases/tag/x86_64).

| Pacote | App |
|---|---|
| `omajim-git` | [Omajim](https://github.com/higorhgon/omajim), cliente XMPP baseado no Gajim |
| `omapass-git` | [omapass](https://github.com/higorhgon/omapass), gerenciador de senhas |
| `herdr-git` | [herdr](https://github.com/higorhgon/herdr), fork com dimming dos panes no estilo do Ghostty e tema do Omarchy; substitui o `herdr` do Omarchy |

## Uso

Acrescente ao `/etc/pacman.conf`:

```ini
[higorhgon]
SigLevel = Optional TrustAll
Server = https://github.com/higorhgon/arch-repo/releases/download/x86_64
```

E instale como qualquer pacote:

```sh
sudo pacman -Syu omajim-git omapass-git herdr-git
```

As atualizações chegam pelo `pacman -Syu` de sempre.

Os pacotes ainda não são assinados, por isso o `SigLevel = Optional TrustAll`.

## Como funciona

- `packages.txt` lista os pacotes: o repositório de cada app e o caminho do
  `PKGBUILD` nele. O `PKGBUILD` fica no repositório do app.
- O workflow roda a cada push aqui, todo dia às 06:00 (horário de Brasília)
  e quando disparado à mão em **Actions → Repositório → Run workflow**.
- `build.sh` compila só os pacotes cuja versão ainda não está publicada, tira
  as versões antigas e refaz o banco `higorhgon.db` com o `repo-add`.

Para incluir um app, acrescente uma linha ao `packages.txt`.
