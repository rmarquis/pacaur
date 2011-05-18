pkgname=pacaur
_pkgname=pacaur
pkgver=0.9.2
pkgrel=1
pkgdesc="A simple cower wrapper to fetch PKGBUILDS from aur & abs"
arch=('any')
url="https://github.com/Spyhawk/pacaur"
license=('GPL')
depends=('cower' 'sudo')
optdepends=('pacman-color: matches output if color is used')
makedepends=('git')
backup=('etc/pacaur.conf')

_gitroot="git://github.com/Spyhawk/pacaur.git"
_gitname="pacaur"

build() {
  cd "$srcdir"
  msg "Connecting to GIT server...."

  if [[ -d $_gitname ]]; then
    cd $_gitname && git pull origin
    msg "The local files are updated."
  else
    git clone $_gitroot && cd $_gitname
  fi

  install -D -m644 ./$_pkgname.conf $pkgdir/etc/$_pkgname.conf || return 1
  install -D -m755 ./$_pkgname $pkgdir/usr/bin/$_pkgname || return 1
}
