all: build publish

build:
	@jekyll --url www.perkin.org.uk

build-test:
	@jekyll --url www-test.perkin.org.uk

test:
	@jekyll --server

publish: build
	@# XXX: https://github.com/mojombo/jekyll/issues/431 says this shouldn't
	@# be required anymore, guess my install is too old...
	@cp .htaccess _site/
	@# Yes, I'm giving away the path to my site.  No, I don't care.
	@rsync -avz --delete _includes/ www.perkin.org.uk:/content/vwww/www.perkin.org.uk/files/
	@rsync -avz --delete --exclude "files" --exclude "tmp" _site/ www.perkin.org.uk:/content/vwww/www.perkin.org.uk/

test-publish: build-test
	@cp .htaccess _site/
	@rsync -avz --delete _includes/ www.perkin.org.uk:/content/vwww/www-test.perkin.org.uk/files/
	@rsync -avz --delete --exclude "files" --exclude "tmp" --exclude "robots.txt" _site/ www.perkin.org.uk:/content/vwww/www-test.perkin.org.uk/
