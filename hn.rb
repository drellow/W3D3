require 'rest-client'
require 'nokogiri'
require 'singleton'
require 'sqlite3'
require 'launchy'

class HN < SQLite3::Database
  include Singleton

  def initialize
    super("hn.db")

    self.results_as_hash = true
    self.type_translation = true
  end
end

def run
  page = Page.new
  page.render_page
  puts "Select a story you want to see!"
  story_choice = gets.chomp.to_i
  page.launch_story(story_choice)
end

class Page

  attr_reader :story_name, :story_url, :story_id, :points, :user_name

  def initialize
    @story_name = []
    @story_url = []
    @story_id = []
    @points = []
    @user_name = []

    scrape
  end

  def scrape
    request = "http://news.ycombinator.com"
    response = RestClient.get(request)
    parsed_html = Nokogiri::HTML(response)

    parsed_html.css("td.title > a").each do |story|
      @story_name << story.text
    end
    parsed_html.css("td.title > a").each do |url|
      @story_url << url.attr('href')
    end
    parsed_html.css("td.subtext > a").each do |story_id|
      @story_id << story_id.attr('href')
      p @story_id
    #  @story_id.select! {|url| url =~ /item\S*/}
    #  @story_id.map! {|id| id[-7..-1]}
    end
    # parsed_html.css("td.subtext > a").each do |user_name|
    #   @user_name << user_name.attr('href')
    #   @user_name.select! {|user| user =~ /user\S*/}
    #   @user_name.map! {|user| user[]}
    # end
    @story_url.pop      # to get rid of the "news2" link text at bottom of page
    @story_name.pop     # to get rid of the "More" button text at bottom of page
    @story_id.pop
  end

  def render_page
    @story_name.each_with_index do |story_name, index|
      puts "#{index + 1}. #{story_name}"
    end
  end

  def launch_story(story_choice)
    story_choice -= 1
    Launchy.open(@story_url[story_choice])
    Story.new(@story_id[story_choice])
  end

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


