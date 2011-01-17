class Category < ActiveRecord::Base
  acts_as_list
  acts_as_tree :order=>"name"
  has_many :categorizations

  has_many :articles,
    :through => :categorizations,
    :order   => "published_at DESC, created_at DESC"


  default_scope :order => 'position ASC'

  module Finders
    def find_all_with_article_counters(maxcount=nil)
      self.find_by_sql([%{
      SELECT categories.id, categories.name, categories.permalink, categories.position, COUNT(articles.id) AS article_counter
      FROM #{Category.table_name} categories
        LEFT OUTER JOIN #{Category.table_name_prefix}categorizations#{Category.table_name_suffix} articles_categories
          ON articles_categories.category_id = categories.id
        LEFT OUTER JOIN #{Article.table_name} articles
          ON (articles_categories.article_id = articles.id AND articles.published = ?)
      GROUP BY categories.id, categories.name, categories.position, categories.permalink
      ORDER BY position
      }, true]).each {|item| item.article_counter = item.article_counter.to_i }
    end

    def find_by_permalink(permalink, options = {})
      with_scope(:find => options) do
        find(:first, :conditions => {:permalink => permalink}) or
          raise ActiveRecord::RecordNotFound
      end
    end
  end
  extend Finders


  def self.to_prefix
    'category'
  end

  def self.reorder(serialized_list)
    self.transaction do
      serialized_list.each_with_index do |cid,index|
        find(cid).update_attribute "position", index
      end
    end
  end

  def self.reorder_alpha
    reorder find(:all, :order => 'UPPER(name)').collect { |c| c.id }
  end

  def stripped_name
    self.name.to_url
  end

  def published_articles
    articles.already_published
  end

  def display_name
    name
  end

  def permalink_url(anchor=nil, only_path=false)
    blog = Blog.default # remove me...

    blog.url_for(
      :controller => '/categories',
      :action => 'show',
      :id => permalink,
      :only_path => only_path
    )
  end

  def to_atom(xml)
    xml.category :term => permalink, :label => name, :scheme => permalink_url
  end

  def to_rss(xml)
    xml.category name
  end

  def to_param
    permalink
  end

  protected

  before_save :set_defaults

  def set_defaults
    self.permalink ||= self.stripped_name
  end

  validates_presence_of :name
  validates_uniqueness_of :name, :on => :create
end
