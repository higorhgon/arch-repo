#!/usr/bin/env bash
# Compila os pacotes de packages.txt cuja versão ainda não está em $1 e deixa
# em $1 só as versões atuais, com o banco do pacman refeito.
# Roda como usuário comum: o makepkg não aceita root.
set -euo pipefail

repo_dir=$(realpath "$1")
repo_name=${REPO_NAME:-higorhgon}
work_dir=$(mktemp -d)
expected=()
changed=0

while read -r name url path; do
	[[ -z $name || $name == \#* ]] && continue

	echo "::group::$name"
	git clone --quiet --depth 1 "$url" "$work_dir/$name"
	cd "$work_dir/$name/$(dirname "$path")"

	# Baixa o código e calcula a versão (pkgver) sem compilar
	makepkg --nobuild --nodeps --noconfirm
	# Sem os pacotes -debug, que a lista traz mesmo quando não são gerados
	mapfile -t files < <(makepkg --packagelist | grep -v -- '-debug-')

	missing=0
	for file in "${files[@]}"; do
		[[ -f $repo_dir/$(basename "$file") ]] || missing=1
		expected+=("$(basename "$file")")
	done

	if ((missing)); then
		makepkg --syncdeps --noconfirm --force
		cp "${files[@]}" "$repo_dir/"
		changed=1
	else
		echo "$name já está atualizado"
	fi
	cd - >/dev/null
	echo "::endgroup::"
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
