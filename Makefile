all: build publish
test: build-test publish-test

build:
	@jekyll build

build-test:
	@jekyll build --config _config.test.yml

localhost:
	@jekyll --server

publish: build
	@# Yes, I'm giving away the path to my site.  No, I don't care.
	@rsync -avz --delete _includes/ www.perkin.org.uk:/content/vwww/www.perkin.org.uk/files/
	@rsync -avz --delete --exclude "files" --exclude "tmp" _site/ www.perkin.org.uk:/content/vwww/www.perkin.org.uk/

publish-test: build-test
	@rsync -avz --delete _includes/ www.perkin.org.uk:/content/vwww/www-test.perkin.org.uk/files/
	@rsync -avz --delete --exclude "files" --exclude "tmp" --exclude "robots.txt" _site/ www.perkin.org.uk:/content/vwww/www-test.perkin.org.uk/
