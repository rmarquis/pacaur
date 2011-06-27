pkgname=pacaur
pkgver=1.2.3
pkgrel=1
pkgdesc="A simple cower wrapper to fetch PKGBUILDS from aur & abs"
arch=('any')
url="https://github.com/Spyhawk/pacaur"
license=('GPL')
depends=('cower' 'expac-git')
optdepends=('pacman-color: colorized output'
            'sudo: install and update packages as non-root')
backup=('etc/pacaur.conf')
source=($pkgname $pkgname.conf README.pod)
md5sums=('0bbce663ce3611dab472ea1302230fc1'
         '2ca5ab1a245f54c7915ef614b9224074'
         '04d539fc6c9b3077e3be2314f4454bb0')
build() {
  mkdir -p "$pkgdir/etc/"
  install -D -m644 ./$pkgname.conf $pkgdir/etc/$pkgname.conf || return 1
  install -D -m755 ./$pkgname $pkgdir/usr/bin/$pkgname || return 1
  mkdir -p "$pkgdir/usr/share/man/man8/"
  pod2man --section=1 --center="Pacaur Manual" --name="PACAUR" --release="$pkgname $pkgver" ./README.pod > $pkgdir/usr/share/man/man8/pacaur.8
}
