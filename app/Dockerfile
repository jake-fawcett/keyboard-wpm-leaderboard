FROM python:3.9.2-slim-buster

# Port used by this container to serve HTTP.
EXPOSE 8000

# Set PORT variable that is used by Gunicorn. This should match "EXPOSE" command.
ENV PORT=8000

# Install system packages.
RUN apt-get update --yes --quiet && apt-get install --yes --quiet --no-install-recommends curl

# Install poetry for management of project requirements.
RUN curl -sSL https://install.python-poetry.org | python3 -

# Install the project requirements.
COPY poetry.lock pyproject.toml /
RUN /root/.local/bin/poetry config virtualenvs.create false
RUN /root/.local/bin/poetry install --no-interaction --no-ansi

# Use /app folder as a directory where the source code is stored.
WORKDIR /app

# Copy the source code of the project into the container.
COPY . .

# Run flask
CMD /root/.local/bin/poetry run gunicorn app:app