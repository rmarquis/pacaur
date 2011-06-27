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
md5sums=('f358354300d82a346df02387ae21c68b'
         '0cdd92d8e4c459d324989d9e87fc42cd'
         'dcf6e55ad7a603619d08c7b2395cb948')
build() {
  mkdir -p "$pkgdir/etc/"
  install -D -m644 ./$pkgname.conf $pkgdir/etc/$pkgname.conf || return 1
  install -D -m755 ./$pkgname $pkgdir/usr/bin/$pkgname || return 1
  mkdir -p "$pkgdir/usr/share/man/man8/"
  pod2man --section=1 --center="Pacaur Manual" --name="PACAUR" --release="$pkgname $pkgver" ./README.pod > $pkgdir/usr/share/man/man8/pacaur.8.gz
}
