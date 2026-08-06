# Strange Blog

## Project description

This project is a strange blog that could be used also as a sort of online Curriculum Vitae.

The application need a database to store information about views of every post but the post itself consists of markdown 
files matching the structure in `posts/template.md.tmpl`

Blog maintainer will publish new article by simply pushing new Markdown files into `post` folder.

### Project workflow
The blog is really simple and probably bad designed in many ways (but carefully designed for DevOps course purpose).
It consists of 2 main part:
- blog posts
- Post views

#### Blog post
Blog post are published by simply adding a new Markdown file to the folder `posts/en`.
All the markdown file must follow the default template provided in `posts/template.md.tmpl`. Specifically, each post 
must have:
- title: blog post title
- subtitle: blog post subtitle
- author: Author Name
- author_image: file_name in static/assets/blog-images for the author profile picture
- date: Date in the format %B %d, %Y
- image: file_name in static/assets/blog-images for the blog picture
- permalink: must be unique
- tags: list,of,comma,separated,tags
- shortcontent: Short abstract of the blog post

finally **three dash** to divide attribute from markdown content, the markdown content below dashes is 
the article real content.

Images are optional and optional parameter must not be inserted in the file.

Every image eventually specified must be placed in the folder `static/assets/blog-imaes` and commit altogether.

#### Post views
To keep track of each post visualisations, a simple table is created in a postgres database using `Flask-SQLAlchemy`.
The table contain simply the post name, that correspond to the permalink, and an integer for post views.

## Project configuration

In order to make it work the requisite are
```
postgresql
python
```

### Configure python environment

(optional) Configure a virtualenv before by installing `python-virtualenv` and executing the command:
```shell
virtualenv venv && source venv/bin/activate
```

To configure python environment simply launch
```shell
pip install -r requirements.txt
```
### Install and configure database
In order to interact with a postgres db, install postgres and create a db (edit configuration in `app.py` accordingly).

Alternatively, deploy a dockered postgres db with the command:
```shell
 docker run --rm --name flask-db-test -e POSTGRES_PASSWORD=passwordhere -e POSTGRES_USER=flask -e POSTGRES_DB=blog postgres
```
- use the parameter '-d' to execute in detached mode, hence release tty
- eventually create a volume to make data permanent, default postgres data inside the container are located at
`/var/lib/postgresql/data`, default path can be changed with the variable `PGDATA`

## First Start
After initial configuration to start the application, the following steps are needed:

```shell
export FLASK_APP=app.py
```
This command will set `app.py` as default Flask app file.

```shell
flask db init
```
This command will initialise db instance.

```shell
flask db migrate
```
Migrate will allow to keep track of db changes and avoid applying them directly or automatically.

```shell
flask db upgrade
```
Upgrade will apply migrated changes to db.

```shell
gunicorn -w 4 -b 0.0.0.0:8080 wsgi:app
```
Finally, start the application by running the above command, in details:
- -w 4 tell gunicorn to use 4 workers
- -b 0.0.0.0:8080 will bin the application to 8080 port
- wsgi:app is the application to run

## Debugging and working locally
For debug purpose it is possible to run the app without using `gunicorn` by simply typing:
```shell
export FLASK_APP=app.py
flask run
```


## DEVOPS assignment

Before starting the with DevOps operation it is really ==IMPORTANT== to understand that the project structure is
suboptimal ==ON PURPOSE==. In fact, no change to the logic of the application is required; the application must be 
considered as a legacy application.

Hence, DevOps changes must concentrate on automation and enhancement of the application's maintainer experience.

### examples

WRONG enhancement:

Insert into the application an exception that handle a date format that do not match the required '%B %d, %Y'
(in example 'January 17, 2020' is correct, '17 January 2020' or 'January 17 2020' or any other date format are not)

This enhancement will serve no purpose, since the maintainer will be able to push a markdown file with the wrong date 
format, and he will have to check through the application (if he ever will) to notice the error.

RIGHT enhancement:

A script called 'check_markdown_validity.sh' that provided a markdown file will check the conformity with markdown 
template. Since, still the maintainer could not care about executing it, a gitlab pipeline step could execute it at each 
new commit for each new markdown file committed.