
CREATE KEYSPACE IF NOT EXISTS "c20379081_keyspace" WITH REPLICATION =
{ 'class': 'SimpleStrategy',
'replication_factor': '3'
};


CREATE TABLE viewer_activity (
        county_id INT,
        fact_key INT,
        viewer_id INT,
        edition_year INT,
        age_group_id INT,
        county_name TEXT,
        participant_name TEXT,
        vote_date DATE,
        viewer_category_id INT,
        votemode TEXT,
        vote INT,
        charge DECIMAL,
        PRIMARY KEY ((county_id), fact_key)
    );
    

SELECT * FROM c20379081_keyspace.viewer_activity

----------------------------------------------------------------------------------------------------------
Indexes

-- My main index!!!!
-- Based on the output of this query before and after the index was implemented with tracing enabled, 
-- the performance has vastly improved in terms of latency and the number of row read is also vastly decreased. 
-- The index enables a single partition query which is the main reason for the vast increase in speed. 
-- The scan before indexing took approx. 13ms seconds but after indexing it only took 4ms and the rows per range searched was reduced from 10933.493 to 0.6375.
-- Chose this index as it allows me to efficntly check the voting breakdown of each partipicant individual which an important task and is quite time consuming without indexing 

TRACING ON;
SELECT * FROM c20379081_keyspace.viewer_activity WHERE participant_name  = 'Zachary Cooper' ALLOW FILTERING;
CREATE index paridx ON c20379081_keyspace.viewer_activity (participant_name);
SELECT * FROM c20379081_keyspace.viewer_activity WHERE participant_name  = 'Zachary Cooper'
drop index c20379081_keyspace.paridx;

-- Second index
-- before index  ' Submitting range requests on 49 ranges with a concurrency of 1 (10933.439 rows per range expected)'
-- after index 'Submitting range requests on 31 ranges with a concurrency of 17 (6.24375 rows per range expected)'
-- rows per range laregly reduced whic proves th eindexing is working and useful for this use case.

TRACING ON;
SELECT * FROM c20379081_keyspace.viewer_activity WHERE edition_year = 2013 ALLOW FILTERING;
CREATE INDEX edidx ON c20379081_keyspace.viewer_activity(edition_year);
SELECT * FROM c20379081_keyspace.viewer_activity WHERE edition_year = 2013;
drop index c20379081_keyspace.edidx;

----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE TABLE viewer_preferences (
	-- unique identifer for the viewer_id, is the primary key
    viewer_id INT PRIMARY KEY,
    name TEXT,
     -- column which is a list of type TEXT, which allows a list of text entries
     --  'FROZEN' is used to store the list as a single value, was needed when dealing with collections.
    favorite_genres FROZEN<LIST<TEXT>>  
);


INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (1, 'John car', ['Comedy', 'Drama']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (2, 'alfie Smith', ['Action', 'Thriller']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (3, 'Michael Black', ['Romance', 'Comedy']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (4, 'Emily Riley', ['Drama', 'Romance']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (5, 'David Wallace', ['Action', 'Adventure']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (6, 'Jessica Oneill', ['Comedy', 'Family']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (7, 'Christopher Lee', ['Science Fiction', 'Action']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (8, 'Orla Rodriguez', ['Drama', 'Mystery']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (9, 'James White', ['Thriller', 'Horror']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (10, 'Sarah Harris', ['Comedy', 'Romantic Comedy']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (11, 'Robert Martinez', ['Drama', 'Crime']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (12, 'Karen Wilson', ['Action', 'Adventure']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (13, 'William Taylor', ['Comedy', 'Drama']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (14, 'Patricia Moore', ['Romance', 'Drama']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (15, 'Richard Anderson', ['Science Fiction', 'Action']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (16, 'Susan Garcia', ['Mystery', 'Thriller']);
INSERT INTO c20379081_keyspace.viewer_preferences (viewer_id, name, favorite_genres) VALUES (17, 'Daniel Brown', ['Comedy', 'Family']);

select * from c20379081_keyspace.viewer_preferences 

---------------------------------------------------------------------------------------------------------------------------------------------


-- This materialized view is useful for querying the viewer_prefernces tbale.
CREATE MATERIALIZED VIEW viewer_genre_view AS
    SELECT viewer_id, name, favorite_genres
    FROM viewer_preferences
    -- the where clause is only rows where 'favorite_genres' and 'viewer_id' are not null.
    -- materialized view needs all elements of the primary key to not be null
    WHERE favorite_genres IS NOT NULL AND viewer_id IS NOT null
	-- 'favorite_genres' is the partition key, data will be partitioned based on this column.
	-- 'viewer_id' is the clustering column, determines the order of rows within the partition.
    -- this ensures the view will support queries that filter by favorite_genres
    PRIMARY KEY (favorite_genres, viewer_id); 

TRACING ON;
SELECT * FROM viewer_genre_view WHERE favorite_genres CONTAINS 'Comedy' ALLOW FILTERING;

