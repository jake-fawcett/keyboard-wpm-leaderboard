from flask import Flask, render_template, request, redirect, url_for
from utils.utils import get_leaderboard_data, check_wpm

app = Flask(__name__)


@app.route("/")
def index():
    return redirect(url_for('leaderboard'))


@app.route("/leaderboard")
def leaderboard():
    get_leaderboard_data()
    print("Leaderboard page request recieved")
    return render_template("leaderboards.html", tables=[get_leaderboard_data()])

@app.route("/submit", methods=["GET", "POST"])
def submitResults():
    print("Submit Results page request recieved")
    if request.method == "POST":
        results = list(request.form.values())
        if "" in results:
            return render_template("submit.html", buttonStatus="Unsuccessful - please enter a valid input.")
        keyboard = results[0]
        username = results[1]
        wpm = results[2]
        result_string = f"Highest WPM for {username} - {keyboard} is {check_wpm(username, keyboard, wpm)['WPM']}"
        return render_template("submit.html", buttonStatus=result_string)
    return render_template("submit.html", buttonStatus="")

if __name__ == "__main__":
    app.run()
