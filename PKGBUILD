# Maintainer: Remy Marquis <remy.marquis at gmail dot com>

pkgname=pacaur
pkgver=2.2.2
pkgrel=1
pkgdesc="A fast workflow AUR wrapper using cower as backend"
arch=('any')
url="https://github.com/Spyhawk/pacaur"
license=('GPL')
depends=('cower' 'expac')
optdepends=('pacman-color: colorized output'
            'sudo: install and update packages as non-root')
backup=('etc/pacaur.conf')
source=($pkgname $pkgname.conf README.pod $pkgname.autocomplete)
md5sums=('f816c34399301c3381393d22621d5e75'
         '291424f94262bc5105a34f06a3992012'
         '4866ecac66c999ba2b9a850f3bb1406e'
         'ad45561278a28c8ff69890f2c23eacd1')
build() {
  mkdir -p "$pkgdir/etc/"
  install -D -m644 ./$pkgname.conf $pkgdir/etc/$pkgname.conf || return 1
  install -D -m755 ./$pkgname $pkgdir/usr/bin/$pkgname || return 1
  install -D -m755 ./$pkgname.autocomplete \
        $pkgdir/etc/bash_completion.d/$pkgname || return 1
  mkdir -p "$pkgdir/usr/share/man/man8/"
  pod2man --section=8 --center="Pacaur Manual" --name="PACAUR" --release="$pkgname $pkgver" ./README.pod > pacaur.8
  install -m 644 ./pacaur.8 $pkgdir/usr/share/man/man8/pacaur.8 
}
