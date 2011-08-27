# Maintainer: Remy Marquis <remy.marquis at gmail dot com>

pkgname=pacaur
pkgver=2.3.1
pkgrel=1
pkgdesc="A fast workflow AUR wrapper using cower as backend"
arch=('any')
url="https://github.com/Spyhawk/pacaur"
license=('GPL')
depends=('cower' 'expac')
optdepends=('pacman-color: colorized output'
            'sudo: install and update packages as non-root')
backup=('etc/pacaur.conf')
source=($pkgname $pkgname.conf README.pod $pkgname.bash.complete)
md5sums=('37baf5a64168afa1c5dfaf9ef61fcfc9'
         'b50b0da4e0a7d0a0ad41aaffa51177da'
         '073f582a30fb369a6a011c27b45b32c1'
         'ad45561278a28c8ff69890f2c23eacd1')
build() {
  mkdir -p "$pkgdir/etc/"
  install -D -m644 ./$pkgname.conf $pkgdir/etc/$pkgname.conf || return 1
  install -D -m755 ./$pkgname $pkgdir/usr/bin/$pkgname || return 1
  install -D -m755 ./$pkgname.bash.complete\
        $pkgdir/etc/bash_completion.d/$pkgname || return 1
  mkdir -p "$pkgdir/usr/share/man/man8/"
  pod2man --section=8 --center="Pacaur Manual" --name="PACAUR" --release="$pkgname $pkgver" ./README.pod > pacaur.8
  install -m 644 ./pacaur.8 $pkgdir/usr/share/man/man8/pacaur.8 
}
