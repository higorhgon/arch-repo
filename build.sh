#!/usr/bin/env bash
# Compila os pacotes de packages.txt cuja versão ainda não está em $1 e deixa
# em $1 só as versões atuais, com o banco do pacman refeito.
# Roda como usuário comum: o makepkg não aceita root.
set -euo pipefail
# O set -e vale também dentro de $(...)
shopt -s inherit_errexit

repo_dir=$(realpath "$1")
repo_name=${REPO_NAME:-higorhgon}
work_dir=$(mktemp -d)
expected=()
changed=0

# Compila um pacote; imprime os arquivos que ele deixa no repositório e
# devolve 2 quando compilou algo novo
build_package() {
	local name=$1 url=$2 path=$3 branch=
	# url#branch lê o PKGBUILD desse branch em vez do padrão
	if [[ $url == *#* ]]; then
		branch=${url#*#}
		url=${url%%#*}
	fi
	if [[ $url == */PKGBUILD ]]; then
		# Um PKGBUILD publicado pelo próprio app, como o da última release
		mkdir -p "$work_dir/$name"
		curl --fail --silent --show-error --location --output "$work_dir/$name/PKGBUILD" "$url" >&2
		cd "$work_dir/$name"
	else
		git clone --quiet --depth 1 ${branch:+--branch "$branch"} "$url" "$work_dir/$name" >&2
		cd "$work_dir/$name/$(dirname "$path")"
	fi

	# Baixa o código e calcula a versão (pkgver) sem compilar
	makepkg --nobuild --nodeps --noconfirm >&2
	# Sem os pacotes -debug, que a lista traz mesmo quando não são gerados
	local files missing=0 file
	mapfile -t files < <(makepkg --packagelist | grep -v -- '-debug-')

	for file in "${files[@]}"; do
		[[ -f $repo_dir/$(basename "$file") ]] || missing=1
		basename "$file"
	done

	if ((missing)); then
		makepkg --syncdeps --noconfirm --force >&2
		cp "${files[@]}" "$repo_dir/"
		return 2
	fi
	echo "$name já está atualizado" >&2
}

failed=()
while read -r name url path; do
	[[ -z $name || $name == \#* ]] && continue

	echo "::group::$name"
	# Fora de um "||", para o set -e valer dentro da função
	set +e
	output=$(
		set -e
		build_package "$name" "$url" "$path" </dev/null
	)
	status=$?
	set -e
	echo "::endgroup::"
	if ((status == 0 || status == 2)); then
		[[ -n $output ]] && mapfile -t -O "${#expected[@]}" expected <<<"$output"
		((status == 2)) && changed=1
	else
		# Um pacote quebrado não segura os outros: a versão publicada fica
		echo "::error::$name não compilou; mantida a versão publicada"
		failed+=("$name")
		for file in "$repo_dir/$name"-[0-9]*.pkg.tar.zst; do
			[[ -e $file ]] && expected+=("$(basename "$file")")
		done
	fi
done <packages.txt

# Tira as versões antigas e os pacotes que saíram da lista
for file in "$repo_dir"/*.pkg.tar.zst; do
	[[ -e $file ]] || continue
	if [[ " ${expected[*]} " != *" $(basename "$file") "* ]]; then
		rm "$file"
		changed=1
	fi
done

if ((changed)) || [[ ! -e $repo_dir/$repo_name.db ]]; then
	rm -f "$repo_dir/$repo_name".{db,files}{,.tar.gz}{,.old}
	repo-add "$repo_dir/$repo_name.db.tar.gz" "$repo_dir"/*.pkg.tar.zst
	# As releases do GitHub não guardam links simbólicos
	for link in "$repo_dir/$repo_name".{db,files}; do
		cp --remove-destination "$(readlink -f "$link")" "$link"
	done
	touch "$repo_dir/.changed"
fi

# O workflow publica o que compilou e só então acusa a falha
if ((${#failed[@]})); then
	printf '%s\n' "${failed[@]}" >"$repo_dir/.failed"
fi
