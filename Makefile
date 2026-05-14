PACKAGE_NAME=launchinfra
VERSION=2.0-5

# REGRA PADRÃO - não falha mesmo se arquivo não existir
all:
	@echo "Construindo $(PACKAGE_NAME) versão $(VERSION)..."
	# Verifica se existe script/fonte e prepara
	@if [ -f launchinfra.sh ]; then chmod +x launchinfra.sh; fi
	@if [ -f launchinfra.py ]; then chmod +x launchinfra.py; fi
	@if [ -f launchinfra ]; then chmod +x launchinfra; fi
	@echo "Build concluído (projeto sem compilação)"

.PHONY: build
build:
	dpkg-buildpackage -us -uc -b

.PHONY: install
install:
	install -D src/launchinfra.sh $(DESTDIR)/usr/bin/launchinfra
	install -D src/lib/logging.sh $(DESTDIR)/usr/share/launchinfra/lib/logging.sh
	install -D src/lib/config.sh $(DESTDIR)/usr/share/launchinfra/lib/config.sh
	install -D src/lib/utils.sh $(DESTDIR)/usr/share/launchinfra/lib/utils.sh
	install -D src/lib/nginx_project.sh $(DESTDIR)/usr/share/launchinfra/lib/nginx_project.sh
	install -D src/lib/cli.sh $(DESTDIR)/usr/share/launchinfra/lib/cli.sh

.PHONY: clean
clean:
	rm -rf debian/.debhelper debian/debhelper-build-stamp debian/files debian/launchinfra debian/*.substvars debian/*.buildinfo debian/*.changes
	rm -f ../$(PACKAGE_NAME)_*.deb
	rm -f launchinfra
	rm -f launchinfra