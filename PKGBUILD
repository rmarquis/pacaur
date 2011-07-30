# Maintainer: Remy Marquis <remy.marquis@gmail.com>

pkgname=pacaur
pkgver=2.2.1
pkgrel=1
pkgdesc="A fast workflow AUR wrapper using cower as backend"
arch=('any')
url="https://github.com/Spyhawk/pacaur"
license=('GPL')
depends=('cower' 'expac')
optdepends=('pacman-color: colorized output'
            'sudo: install and update packages as non-root')
backup=('etc/pacaur.conf')
source=($pkgname $pkgname.conf README.pod)
md5sums=('5e961af559a7a74b09647374365b947a'
         '291424f94262bc5105a34f06a3992012'
         '4baf408fc782faaf814110d31a2fc108')
build() {
  mkdir -p "$pkgdir/etc/"
  install -D -m644 ./$pkgname.conf $pkgdir/etc/$pkgname.conf || return 1
  install -D -m755 ./$pkgname $pkgdir/usr/bin/$pkgname || return 1
  mkdir -p "$pkgdir/usr/share/man/man8/"
  pod2man --section=8 --center="Pacaur Manual" --name="PACAUR" --release="$pkgname $pkgver" ./README.pod > pacaur.8
  install -m 644 ./pacaur.8 $pkgdir/usr/share/man/man8/pacaur.8 
}
