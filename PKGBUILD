pkgname=pacaur
pkgver=1.0.1
pkgrel=1
pkgdesc="A simple cower wrapper to fetch PKGBUILDS from aur & abs"
arch=('any')
url="https://github.com/Spyhawk/pacaur"
license=('GPL')
depends=('cower' 'sudo' 'expac-git')
optdepends=('pacman-color: matches output if color is used')
backup=('etc/pacaur.conf')
source=($pkgname $pkgname.conf)
md5sums=('38e252e8c43d5de8030aa167e1e060ea'
         '2ca5ab1a245f54c7915ef614b9224074')
build() {
  mkdir -p "$pkgdir/etc/"
  install -D -m644 ./$pkgname.conf $pkgdir/etc/$pkgname.conf || return 1
  install -D -m755 ./$pkgname $pkgdir/usr/bin/$pkgname || return 1
}
