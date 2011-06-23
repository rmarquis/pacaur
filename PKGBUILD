pkgname=pacaur
pkgver=1.1.0
pkgrel=1
pkgdesc="A simple cower wrapper to fetch PKGBUILDS from aur & abs"
arch=('any')
url="https://github.com/Spyhawk/pacaur"
license=('GPL')
depends=('cower' 'sudo' 'expac-git')
optdepends=('pacman-color: matches output if color is used')
backup=('etc/pacaur.conf')
source=($pkgname $pkgname.conf)
md5sums=('8750f57644054472265ef1bbc09b0bd1'
         '2ca5ab1a245f54c7915ef614b9224074')
build() {
  mkdir -p "$pkgdir/etc/"
  install -D -m644 ./$pkgname.conf $pkgdir/etc/$pkgname.conf || return 1
  install -D -m755 ./$pkgname $pkgdir/usr/bin/$pkgname || return 1
}
