# arch-repo

Repositório pacman com os meus apps para Arch Linux, compilado pelo GitHub
Actions e publicado na release [`x86_64`](../../releases/tag/x86_64).

| Pacote | App |
|---|---|
| `omajim-git` | [Omajim](https://github.com/higorhgon/omajim), cliente XMPP em C++/Qt para o Omarchy |
| `omapass-git` | [omapass](https://github.com/higorhgon/omapass), gerenciador de senhas |
| `herdr-git` | [herdr](https://github.com/higorhgon/herdr), fork com dimming dos panes no estilo do Ghostty e tema do Omarchy; substitui o `herdr` do Omarchy |
| `gmk67-git` | [GMK67](https://github.com/higorhgon/gmk67-rgb), luzes, teclas e macros do teclado Zuoya GMK67 em C++/Qt, com efeitos animados ao vivo |
| `monitor-noticias-bin` | [Monitor de notícias](https://github.com/Nerqs/monitor-noticias), notícias de tecnologia e falhas críticas priorizadas para a sua stack (de um colega; o PKGBUILD é o que ele publica em cada release) |

## Uso

Acrescente ao `/etc/pacman.conf`:

```ini
[higorhgon]
SigLevel = Optional TrustAll
Server = https://github.com/higorhgon/arch-repo/releases/download/x86_64
```

E instale como qualquer pacote:

```sh
sudo pacman -Syu omajim-git omapass-git herdr-git gmk67-git monitor-noticias-bin
```

As atualizações chegam pelo `pacman -Syu` de sempre.

O `omajim-git` é o Omajim em C++/Qt. Ele substitui a versão em Python, que
tinha o mesmo nome, e o antigo `omajim-qt`: quem tem um deles instalado
recebe o novo no `pacman -Syu`.

Os pacotes ainda não são assinados, por isso o `SigLevel = Optional TrustAll`.

### No Omarchy

O `omarchy refresh pacman`, que também roda ao trocar de canal com
`omarchy channel set`, sobrescreve o `/etc/pacman.conf` inteiro com o modelo
do Omarchy e apaga o bloco acima. Para o repositório sobreviver, deixe o bloco
num arquivo próprio e use o hook `pre-refresh-pacman`. Esse hook roda logo
depois do refresh e antes da atualização dos pacotes, e coloca o `Include` de
volta:

```sh
# 1. O bloco do repositório num arquivo que o Omarchy não toca
sudo tee /etc/pacman.d/custom-repos.conf >/dev/null <<'EOF'
[higorhgon]
SigLevel = Optional TrustAll
Server = https://github.com/higorhgon/arch-repo/releases/download/x86_64
EOF

# 2. No pacman.conf, só a linha Include (remove o bloco antigo, se houver)
sudo sed -i '/^\[higorhgon\]/,/^Server = .*arch-repo/d' /etc/pacman.conf
grep -qxF 'Include = /etc/pacman.d/custom-repos.conf' /etc/pacman.conf ||
  echo 'Include = /etc/pacman.d/custom-repos.conf' | sudo tee -a /etc/pacman.conf

# 3. Ativa o hook de exemplo que o Omarchy já traz
mv ~/.config/omarchy/hooks/pre-refresh-pacman.d/add-custom-repo{.sample,}

# 4. Confere
sudo pacman -Sy && pacman -Sl higorhgon
```

O hook recoloca o `Include` antes do `[core]`. Com isso, este repositório tem
prioridade sobre os oficiais quando um pacote tem o mesmo nome. Hoje nenhum
tem: os nomes daqui só existem aqui.

## Como funciona

- `packages.txt` lista os pacotes: o repositório de cada app e o caminho do
  `PKGBUILD` nele. O `PKGBUILD` fica no repositório do app; `url#branch` lê de
  outro branch que não o padrão. Uma URL terminada em `/PKGBUILD` baixa um
  PKGBUILD publicado pelo próprio app, como o da última release.
- O workflow roda a cada push aqui, todo dia às 06:00 (horário de Brasília)
  e quando disparado à mão em **Actions → Repositório → Run workflow**.
- `build.sh` compila só os pacotes cuja versão ainda não está publicada, tira
  as versões antigas e refaz o banco `higorhgon.db` com o `repo-add`. Um pacote
  que não compila não segura os outros: a versão publicada dele fica, e o
  workflow termina com erro apontando qual foi.
- O `herdr-git` compila a última release estável do herdr com os commits do
  fork por cima, então cada release nova chega no build diário seguinte.

Para incluir um app, acrescente uma linha ao `packages.txt`.
