require 'rubygems'
require 'sinatra'
require 'sinatra/mongomapper'
require 'haml'
require 'json'
require 'cgi'

# TODO: Use Tmdb to get movie posters and movie ratings

set :mongomapper, 'mongomapper://localhost:27017/mit'

Timeline = (1888..Time.now.year).to_a

Genres = ['Action',
          'Adventure',
          'Adult',
          'Animation',
          'Comedy',
          'Crime',
          'Documentary',
          'Drama',
          'Fantasy',
          'Family',
          'Film-Noir',
          'Horror',
          'Musical',
          'Mystery',
          'Romance',
          'Sci-Fi',
          'Short',
          'Thriller',
          'War',
          'Western']

YearsPerPage = 10
GenresPerPage = 5

class Movie
  include MongoMapper::Document

  attr_accessor :title_url

  key :title, String
  key :year, Integer
  key :genres, Array
  key :votes, Integer
  key :rating, Float

  scope :released_in, lambda { |year| where(:year => year) }
  scope :in_genre, lambda { |genre| where(:genres => {:$all => [genre]}) }

  def title_url
    CGI.escape self.title
  end
end

# /              = timeline with years
# /page/{page}

# /{year}        = overall view of genres with scrollable (vertical) list
# /{year}/page/{page} = same as above, but a specific page (above defaults to 1)
#                  Both query the url below using ajax to get the genre movies
# /{year}/genre/{genre}/page/{page}
# /movie/{movie} = general info page about the movie
#

get '/' do
  @page = Page.new('', Timeline.reverse, YearsPerPage, 1)
  redirect to(@page.redirect_url) if @page.needs_redirect?
  haml :index
end

get '/page/:page_num/?' do |page_num|
  @page = Page.new('', Timeline.reverse, YearsPerPage, page_num.to_i)
  redirect to(@page.redirect_url) if @page.needs_redirect?
  haml :index
end

get '/:year/?' do |year|
  @year = year
  @page = Page.new("/#{year}", Genres, GenresPerPage, 1)
  @movies = Hash.new
  @page.items.each do |genre|
    @movies[genre] = movie_list(year, genre, 1)
  end
  haml :year
end

get '/:year/page/:page_num/?' do |year, page_num|
  @year = year
  @page = Page.new("/#{year}", Genres, GenresPerPage, page_num.to_i)
  @movies = Hash.new
  @page.items.each do |genre|
    @movies[genre] = movie_list(year, genre, 1)
  end
  haml :year
end

get '/:year/genre/:genre/?', :provides => 'json' do |year, genre|
  movies = movie_list(year, genre, 1)
  { :movies => movies }.to_json
end

get '/:year/genre/:genre/page/:page/?', :provides => 'json' do |year, genre, page|
  movies = movie_list(year, genre, page.to_i)
  { :movies => movies }.to_json
end

get '/movie/:movie/?' do
  haml :movie
end

def movie_list(year, genre, page)
  genre.capitalize!

  Movie.released_in(year.to_i)
       .in_genre(genre)
       .sort(:votes.desc)
       .sort(:rating.desc)
       .paginate({
            #:order => :rating.desc,
            :per_page => 5,
            :page => page,
       })
end

class Page
  attr_accessor :items, :count, :next, :previous

  def initialize(base_url, list, items_per_page, page_num)
    @base_url = base_url
    @list = list
    @size = items_per_page
    @number = page_num
  end

  def needs_redirect?
    @number > self.count || @number <= 0
  end

  def redirect_url
    if @number > self.count
      return "#{@base_url}/page/#{self.count}"
    elsif @number <= 0
      return "#{@base_url}/page/1"
    end
  end

  def items
    @list[(@number * @size) - @size, @size]
  end

  def count
    if @list.count % @size != 0
      return @list.count / @size + 1
    end
    @list.count / @size
  end

  def next
    return nil if @number == self.count
    @number + 1
  end

  def previous
    return nil if @number == 1
    @number - 1
  end
end
