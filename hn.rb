require 'rest-client'
require 'nokogiri'
require 'singleton'
require 'sqlite3'

def run
  # scrapes front page, gives index, link name
  # asks for index to access page
  # user selects a story to access
  # creates story object
  # reads readers from story object
  # hit B to go back to main page -> runs run method
end

def front_page
  # scrape front page for story_id, story_name
  # store this crap in an array
  # puts each line of array
end


class HN < SQLite3::Database
  include Singleton

  def initialize
    super("hn.db")

    self.results_as_hash = true
    self.type_translation = true
  end
end


def front_page
  request = "http://news.ycombinator.com"
  response = RestClient.get(request)
  parsed_html = Nokogiri::HTML(response)
end


def comment_links
  link_array = []
  array = front_page.css("td.subtext > a")
  array.each do |link|
    link_array << link.attr('href')
  end
  link_array.select! {|url| url =~ /item\S*/}
end

def url_builder
  comment_links.map! do |link|
    "http://news.ycombinator.com/#{link}"
  end
end

def scrape

    full_link = "http://news.ycombinator.com/item?id=5104964"

    response = RestClient.get(full_link)
    parsed_html = Nokogiri::HTML(response)

    story_id = full_link[-7..-1]
    puts story_id
    story = parsed_html.css("td.title > a")
    story_link = story.attr('href')
    story_name = story.text
    puts story_name
    puts story_link
    username = parsed_html.css("td.subtext > a")[0].text
    puts username
    story_score = parsed_html.css("span#score_#{story_id}").text.split[0].to_i
    puts story_score

    store(story_id, story_name, story_link, username, story_score)
end

class Story

  attr_reader :story_id, :story_name, :story_url, :user_name, :points

  def initialize(story_id)
    @story_id = story_id
    @url = "http://news.ycombinator.com/item?id=#{@story_id}"

    response = RestClient.get(@url)
    parsed_html = Nokogiri::HTML(response)

    story = parsed_html.css("td.title > a")
    @story_url = story.attr('href').value
    @story_name = story.text
    @user_name = parsed_html.css("td.subtext > a")[0].text
    @points = parsed_html.css("span#score_#{story_id}").text.split[0].to_i
    @comment_ids = []
    parsed_html.css("td.default > div > span.comhead > a").each do |link|
      @comment_ids << link.attr('href')
    end
    @comment_ids.select! {|url| url =~ /item\S*/}
    @comment_ids.map! {|id| id[-7..-1]}
    make_comments(@comment_ids) #<< launches factory method on array of IDs


    store(@story_id, @story_name, @story_url, @user_name, @points)
  end


  def make_comments(comment_ids)
    @comments = []
    comment_ids.each do |comment_id|
      sleep(1)
      @comments << Comment.new(comment_id, @story_id)
    end
  end

  def comment_bodies
    @comments.each do |comment|
      puts "#{comment.user_name} said: #{comment.body}"
    end
  end

  def store(story_id, story_name, story_url, user_name, points)
    HN.instance.execute("INSERT INTO stories ('id', 'story_name', 'story_url', 'user_name',
      'points') VALUES (?, ?, ?, ?, ?)", story_id, story_name, story_url, 
      user_name, points)
  end

end

class Comment

  attr_reader :comment_id, :story_id, :user_name, :parent_id, :body

  def initialize(comment_id, story_id)
    @story_id = story_id
    @comment_id = comment_id
    @url = "http://news.ycombinator.com/item?id=#{@comment_id}"

    response = RestClient.get(@url)
    parsed_html = Nokogiri::HTML(response)

    @user_name = parsed_html.css("td.default > div > span.comhead > a")[0].text
    @parent_id = parsed_html.css("td.default > div > span.comhead > a")[2].attr('href')[-7..-1]
    @body = parsed_html.css("span.comment > font")[0].text

    store(@comment_id, @story_id, @user_name, @parent_id, @body)
  end

  def store(comment_id, story_id, user_name, parent_id, body)
    HN.instance.execute("INSERT INTO comments ('id', 'story_id', 'user_name', 
      'parent_id', 'body') VALUES (?, ?, ?, ?, ?)", comment_id, story_id, user_name, 
       parent_id, body)
  end

end


