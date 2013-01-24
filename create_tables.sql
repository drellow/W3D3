CREATE TABLE stories (
  id INTEGER PRIMARY KEY,
  story_name VARCHAR(255),
  story_url VARCHAR(255),
  user_name VARCHAR(255),
  points INTEGER
);


CREATE TABLE comments (
  id INTEGER PRIMARY KEY,
  story_id INTEGER,
  user_name VARCHAR(255),
  parent_id INTEGER,
  body MediumText
);
