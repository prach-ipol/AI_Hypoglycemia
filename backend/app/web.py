from flask import Blueprint, render_template

web = Blueprint("web", __name__)

@web.get("/")
def home(): return render_template("home.html", page="home")

@web.get("/intake")
def intake(): return render_template("intake.html", page="intake")

@web.get("/login")
def login_page(): return render_template("login.html", page="login")

@web.get("/register")
def register_page(): return render_template("register.html", page="register")
