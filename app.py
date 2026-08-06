#!/usr/bin/env python
# -*- coding: utf-8 -*-

import markdown
import sys
from datetime import datetime as dt
from flask import Flask, render_template
from flask_flatpages import FlatPages
from flask_frozen import Freezer

from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate

app = Flask(__name__)
freezer = Freezer(app)

app.config['SQLALCHEMY_DATABASE_URI'] = "postgresql://flask:passwordhere@172.17.0.2:5432/blog"
db = SQLAlchemy(app)
migrate = Migrate(app, db)


FLATPAGES_EXTENSION = '.md'
FLATPAGES_ROOT = ''
POST_DIR = 'posts'
POST_PER_PAGE = 10

flatpages = FlatPages(app)
app.config.from_object(__name__)

class PostViews(db.Model):
    __tablename__ = 'post_views'

    id = db.Column(db.Integer, primary_key=True)
    post_name = db.Column(db.String())
    views = db.Column(db.Integer())

    def __init__(self, post_name, views=0):
        self.post_name = post_name
        self.views = views

    def __repr__(self):
        return f"<Post {self.name}>"

def get_or_create(session, model, defaults=None, **kwargs):
    instance = session.query(model).filter_by(**kwargs).one_or_none()
    if instance:
        return instance, False
    else:
        kwargs |= defaults or {}
        instance = model(**kwargs)
        try:
            session.add(instance)
            session.commit()
        except Exception:
            session.rollback()
            instance = session.query(model).filter_by(**kwargs).one()
            return instance, False
        else:
            return instance, True



@app.route("/")
@app.route("/home")
def home():
    posts = [p for p in flatpages if p.path.startswith('posts/en')]
    posts.sort(key=lambda item:dt.strptime(item['date'], "%B %d, %Y"), reverse=True)
    return render_template("home.html", posts=posts[:min(len(posts),3)])

@app.route("/blog", defaults={'page': 0})
@app.route("/blog/page/<int:page>")
def blog(page):
    posts = [p for p in flatpages if p.path.startswith('posts/en')]
    posts.sort(key=lambda item:dt.strptime(item['date'], "%B %d, %Y"), reverse=True)
    return render_template("blog.html", 
        previous_page=page-1 if page>0 else -1,
        next_page=page+1 if len(posts)>(page+1)*POST_PER_PAGE else 0,
        posts=posts[min(len(posts), POST_PER_PAGE)*page:min(len(posts), POST_PER_PAGE)*(page+1)])

@app.route("/blog/<permalink>")
def blog_post(permalink):
    path = '{}/{}'.format('posts/en', permalink)
    post = flatpages.get_or_404(path)
    if post:
        db_post, created = get_or_create(db.session, PostViews, post_name=permalink)
        db_post.views += 1
        db.session.commit()
    return render_template('post.html', post=post)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "build":
        freezer.freeze()
    else:
        app.run(host='0.0.0.0', debug=True)
