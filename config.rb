# Activate and configure extensions
# https://middlemanapp.com/advanced/configuration/#configuring-extensions

activate :autoprefixer do |prefix|
  prefix.browsers = "last 2 versions"
end

# Layouts
# https://middlemanapp.com/basics/layouts/

# Per-page layout changes
page "/*.xml", layout: false
page "/*.json", layout: false
page "/*.txt", layout: false

# With alternative layout
# page "/path/to/file.html", layout: "other_layout"

# Proxy pages
# https://middlemanapp.com/advanced/dynamic-pages/

# proxy(
#   "/this-page-has-no-template.html",
#   "/template-file.html",
#   locals: {
#     which_fake_page: "Rendering a fake page with a local variable"
#   },
# )

proxy("/kolekcje.html", "/collections.html", ignore: true)

released_books = []

YAML.load_file("data/collections.yml").each do |collection|
  next unless File.exist?("data/collection/#{collection["slug"]}.yml")

  proxy(
    "/kolekcje/#{collection["slug"]}.html",
    "/collection.html",
    locals: {
      collection_slug: collection["slug"]
    },
    ignore: true
  )

  YAML.load_file("data/collection/#{collection["slug"]}.yml").each_with_index do |book, index|
    next unless book["isbn"]
    next unless File.exist?("data/isbn/#{collection["slug"]}/#{(index + 1).to_s.rjust(3, "0")}.#{book["isbn"]}.yml")

    proxy(
      "/ksiazka/#{book["isbn"]}.html",
      "/book.html",
      locals: {
        collection_slug: collection["slug"],
        book_isbn: book["isbn"],
        book_number: index + 1
      },
      ignore: true
    )

    if File.exist?("data/isbn/#{collection["slug"]}/#{(index + 1).to_s.rjust(3, "0")}.#{book["isbn"]}.yml")
      released_books << YAML.load_file("data/isbn/#{collection["slug"]}/#{(index + 1).to_s.rjust(3, "0")}.#{book["isbn"]}.yml")
    end
  end
end

book_page_size = 12
set :book_page_size, book_page_size
released_books = released_books.select { |book| book["release_date"] != "" && Date.parse(book["release_date"]) <= Date.today }
book_pages = (1..(released_books.size)).to_a.each_slice(book_page_size).to_a.size
book_pages = book_pages > 0 ? book_pages : 1
set :last_book_page, book_pages

(1..book_pages).each do |page|
  proxy(
    "/#{page}.html",
    "index2.html",
    locals: {
      page: page
    },
    ignore: true
  )
end

proxy("/serie.html", "/volumes.html", ignore: true)

Dir.glob("../comic_vine/volumes/*.json").each do |path|
  volume_id = File.basename(path, ".json")

  proxy(
    "/seria/#{volume_id}.html",
    "volume.html",
    locals: {
      volume_id: volume_id
    },
    ignore: true
  )
end

set :book_cover_base_url, "http://localhost:8880/images/"
set :issue_cover_base_url, "http://localhost:8881/images/"

# Helpers
# Methods defined in the helpers block are available in templates
# https://middlemanapp.com/basics/helper-methods/

helpers do
  def collection_dict
    unless @collection_dict
      @collection_dict = data.collections.map do |collection|
        [collection.slug, { name: collection.name, slug: collection.slug, publisher: collection.publisher }]
      end.to_h
    end

    @collection_dict
  end

  def books
    slugs = data.collections.map { |collection| collection.slug }
    books = []
    slugs.each do |slug|
      next unless data.collection[slug]

      data.collection[slug].each_with_index do |book, index|
        next unless data.isbn[slug]
        next unless data.isbn[slug]["#{(index + 1).to_s.rjust(3, "0")}.#{book.isbn}"]

        isbn_data = data.isbn[slug] && data.isbn[slug]["#{(index + 1).to_s.rjust(3, "0")}.#{book.isbn}"]
        next if isbn_data.release_date == ""
        next if Date.parse(isbn_data.release_date) > Date.today

        book.release_date = isbn_data.release_date
        book.collection_slug = slug
        book.collection_name = collection_dict[slug][:name]
        book.publisher = collection_dict[slug][:publisher]
        book.number = index + 1

        books << book
      end
    end

    books.sort_by { |book| [Date.parse(book.release_date), book.collection, book.name, book.number] }.reverse
  end

  def comic_vine_issue(id)
    file_path = "../comic_vine/issues/#{id}.json"

    if File.exist?(file_path)
      YAML.load_file(file_path)
    else
      {}
    end
  end

  def comic_vine_volume(id)
    file_path = "../comic_vine/volumes/#{id}.json"

    if File.exist?(file_path)
      YAML.load_file(file_path)
    else
      {}
    end
  end

  def books_exist_count(collection_slug)
    books = YAML.load_file("data/collection/#{collection_slug}.yml")
    checks =
      books.map.with_index do |book, index|
        File.exist?("data/isbn/#{collection_slug}/#{(index+1).to_s.rjust(3, "0")}.#{book["isbn"]}.yml")
      end
    checks.count(true)
  end

  def grouped_volumes
    Dir.glob("../comic_vine/volumes/*.json")
      .map { |path| JSON.parse(File.read(path)) }
      .sort_by { |volume| [volume["start_year"].to_i, volume["name"]] }
      .group_by { |volume| volume["start_year"].to_i }
  end

  def get_volume(volume_id)
    JSON.parse(File.read("../comic_vine/volumes/#{volume_id}.json"))
  end
end

# Build-specific configuration
# https://middlemanapp.com/advanced/configuration/#environment-specific-settings

# configure :build do
#   activate :minify_css
#   activate :minify_javascript
# end

configure :build do
  set :images_dir, "katalog-static/images"

  set :book_cover_base_url, "https://katalog-komiksow.github.io/book_covers/images/"
  set :issue_cover_base_url, "https://katalog-komiksow.github.io/issue_covers_thumb/images/"
end
