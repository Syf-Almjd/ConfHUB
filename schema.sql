-- ---------------------------------------------------------------
-- 1. TYPES DEFINITION
-- ---------------------------------------------------------------
CREATE OR REPLACE TYPE ConferenceTY AS OBJECT (
    acronym VARCHAR2(20),
    name    VARCHAR2(100),
    url     VARCHAR2(200),
    venue   VARCHAR2(100)
);
/

-- Member represents Program Committee members and Organizers
CREATE OR REPLACE TYPE MemberTY AS OBJECT (
    id           VARCHAR2(20),
    name         VARCHAR2(100),
    affiliation  VARCHAR2(100),
    email        VARCHAR2(100),
    phone        VARCHAR2(20),
    is_organizer CHAR(1)          -- 'Y' = organizer, 'N' = reviewer only
);
/

CREATE OR REPLACE TYPE AuthorTY AS OBJECT (
    id                VARCHAR2(20),
    name              VARCHAR2(100),
    affiliation       VARCHAR2(100),
    email             VARCHAR2(100),
    phone             VARCHAR2(20),
    is_contact_author CHAR(1)     -- 'Y' = can be set as contact author
);
/

CREATE OR REPLACE TYPE SponsorTY AS OBJECT (
    id             VARCHAR2(20),
    name           VARCHAR2(100),
    funding_amount NUMBER,
    funding_date   DATE
);
/

-- Article parent entity; subtypes (Research Paper, Industrial Paper,
-- Poster, Short Paper, Tutorial) are distinguished via the category column.
-- No separate sub-tables needed — all author info is required by default.
CREATE OR REPLACE TYPE ArticleTY AS OBJECT (
    id             VARCHAR2(20),
    title          VARCHAR2(200),
    status         VARCHAR2(20),
    is_published   CHAR(1),
    category       VARCHAR2(30),   -- subtype discriminator
    research_area  VARCHAR2(100),
    contact_author REF AuthorTY
);
/

CREATE OR REPLACE TYPE ScoreTY AS OBJECT (
    id           VARCHAR2(20),
    originality  INTEGER,
    signification INTEGER,         -- named per spec (significance)
    quality      INTEGER,
    global_score NUMBER,
    comments     VARCHAR2(500),
    reviewer     REF MemberTY,
    article      REF ArticleTY
);
/

-- ---------------------------------------------------------------
-- 2. TABLES DEFINITION
-- ---------------------------------------------------------------
CREATE TABLE Conference OF ConferenceTY (
    acronym PRIMARY KEY,
    name    NOT NULL,
    url     NOT NULL,
    venue   NOT NULL
);

-- email and phone are required for all members (per spec note)
CREATE TABLE Member OF MemberTY (
    id           PRIMARY KEY,
    name         NOT NULL,
    affiliation  NOT NULL,
    email        NOT NULL,
    phone        NOT NULL,
    is_organizer NOT NULL,
    CONSTRAINT chk_member_organizer CHECK (is_organizer IN ('Y','N'))
);

-- email and phone are required for all authors (per spec note)
CREATE TABLE Author OF AuthorTY (
    id                PRIMARY KEY,
    name              NOT NULL,
    affiliation       NOT NULL,
    email             NOT NULL,
    phone             NOT NULL,
    is_contact_author NOT NULL,
    CONSTRAINT chk_author_contact CHECK (is_contact_author IN ('Y','N'))
);

CREATE TABLE Sponsor OF SponsorTY (
    id             PRIMARY KEY,
    name           NOT NULL,
    funding_amount NOT NULL,
    funding_date   NOT NULL,
    CONSTRAINT chk_sponsor_funding CHECK (funding_amount > 0)
);

-- Article IS-A hierarchy: category column acts as subtype discriminator.
-- Subtypes: research_paper, industrial_paper, poster, short_paper, tutorial.
-- No separate sub-tables — author info required by default for all.
CREATE TABLE Article OF ArticleTY (
    id             PRIMARY KEY,
    title          NOT NULL,
    status         NOT NULL,
    is_published   NOT NULL,
    category       NOT NULL,
    research_area  NOT NULL,
    contact_author NOT NULL,
    CONSTRAINT chk_article_status    CHECK (status IN ('pending','accepted','rejected')),
    CONSTRAINT chk_article_published CHECK (is_published IN ('Y','N')),
    CONSTRAINT chk_article_category  CHECK (
        category IN ('research_paper','industrial_paper','tutorial','short_paper','poster')
    )
);

CREATE TABLE Score OF ScoreTY (
    id            PRIMARY KEY,
    originality   NOT NULL,
    signification NOT NULL,
    quality       NOT NULL,
    reviewer      NOT NULL,
    article       NOT NULL,
    CONSTRAINT chk_score_orig CHECK (originality   BETWEEN 1 AND 10),
    CONSTRAINT chk_score_sign CHECK (signification BETWEEN 1 AND 10),
    CONSTRAINT chk_score_qual CHECK (quality       BETWEEN 1 AND 10)
);

-- ---- Relationship Tables ----

-- organizes (N:M): Member organizes Conference
CREATE TABLE Organizes (
    member_ref     REF MemberTY     SCOPE IS Member,
    conference_ref REF ConferenceTY SCOPE IS Conference
);

-- write (N:M): Author writes Article
CREATE TABLE Writes (
    author_ref  REF AuthorTY  SCOPE IS Author,
    article_ref REF ArticleTY SCOPE IS Article
);

-- part of (1:N): Article submitted to Conference
CREATE TABLE Submits (
    article_ref    REF ArticleTY    SCOPE IS Article,
    conference_ref REF ConferenceTY SCOPE IS Conference
);

-- Reviewer (N:M): Member reviews Article
CREATE TABLE AssignedTo (
    member_ref  REF MemberTY  SCOPE IS Member,
    article_ref REF ArticleTY SCOPE IS Article
);

-- fund (N:M): Sponsor funds Conference
CREATE TABLE Funds (
    sponsor_ref    REF SponsorTY    SCOPE IS Sponsor,
    conference_ref REF ConferenceTY SCOPE IS Conference
);

-- Index for score querying
CREATE INDEX Score_GlobalScore_Index ON Score(global_score);

-- ---------------------------------------------------------------
-- 3. TRIGGERS
-- ---------------------------------------------------------------

-- Enforce: an article can only be submitted to one conference
CREATE OR REPLACE TRIGGER trg_article_single_conference
FOR INSERT ON Submits
COMPOUND TRIGGER
    TYPE t_id_tbl IS TABLE OF VARCHAR2(20) INDEX BY PLS_INTEGER;
    g_article_ids t_id_tbl;
    g_idx         PLS_INTEGER := 0;

    BEFORE EACH ROW IS
        v_art_id VARCHAR2(20);
    BEGIN
        SELECT DEREF(:NEW.article_ref).id INTO v_art_id FROM DUAL;
        g_idx := g_idx + 1;
        g_article_ids(g_idx) := v_art_id;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_count INTEGER;
    BEGIN
        FOR i IN 1..g_idx LOOP
            SELECT COUNT(*) INTO v_count FROM Submits su
            WHERE DEREF(su.article_ref).id = g_article_ids(i);
            IF v_count > 1 THEN
                g_article_ids.DELETE;
                g_idx := 0;
                RAISE_APPLICATION_ERROR(-20001, 'Error: Article already submitted to a conference');
            END IF;
        END LOOP;
        g_article_ids.DELETE;
        g_idx := 0;
    END AFTER STATEMENT;
END trg_article_single_conference;
/

-- Enforce: reviewer must organize the conference the article belongs to
CREATE OR REPLACE TRIGGER trg_reviewer_must_organize
BEFORE INSERT ON AssignedTo
FOR EACH ROW
DECLARE
    v_conference_ref REF ConferenceTY;
    v_count          INTEGER;
BEGIN
    SELECT conference_ref INTO v_conference_ref FROM Submits WHERE article_ref = :NEW.article_ref;
    SELECT COUNT(*) INTO v_count FROM Organizes WHERE member_ref = :NEW.member_ref AND conference_ref = v_conference_ref;
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error: Reviewer does not organize this conference');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error: Article has not been submitted to any conference');
END trg_reviewer_must_organize;
/

-- Enforce: a reviewer cannot be an author of the article they review
CREATE OR REPLACE TRIGGER trg_reviewer_not_author
BEFORE INSERT ON AssignedTo
FOR EACH ROW
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM Writes w
    WHERE w.article_ref = :NEW.article_ref AND DEREF(w.author_ref).id = DEREF(:NEW.member_ref).id;
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Error: Reviewer is an author of this article');
    END IF;
END trg_reviewer_not_author;
/

-- Enforce: maximum 4 reviewers per article
CREATE OR REPLACE TRIGGER trg_reviewer_count
FOR INSERT ON AssignedTo
COMPOUND TRIGGER
    TYPE t_id_tbl IS TABLE OF VARCHAR2(20) INDEX BY PLS_INTEGER;
    g_article_ids t_id_tbl;
    g_idx         PLS_INTEGER := 0;

    BEFORE EACH ROW IS
        v_art_id VARCHAR2(20);
    BEGIN
        SELECT DEREF(:NEW.article_ref).id INTO v_art_id FROM DUAL;
        g_idx := g_idx + 1;
        g_article_ids(g_idx) := v_art_id;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_count INTEGER;
    BEGIN
        FOR i IN 1..g_idx LOOP
            SELECT COUNT(*) INTO v_count FROM AssignedTo
            WHERE DEREF(article_ref).id = g_article_ids(i);
            IF v_count > 4 THEN
                g_article_ids.DELETE;
                g_idx := 0;
                RAISE_APPLICATION_ERROR(-20004, 'Error: Article already has maximum 4 reviewers');
            END IF;
        END LOOP;
        g_article_ids.DELETE;
        g_idx := 0;
    END AFTER STATEMENT;
END trg_reviewer_count;
/

-- Auto-compute global_score = (originality + signification + quality) / 3
CREATE OR REPLACE TRIGGER trg_global_score
BEFORE INSERT OR UPDATE ON Score
FOR EACH ROW
BEGIN
    :NEW.global_score := (:NEW.originality + :NEW.signification + :NEW.quality) / 3;
END trg_global_score;
/

-- Enforce: score components must be in range 1-10
CREATE OR REPLACE TRIGGER trg_score_range
BEFORE INSERT OR UPDATE ON Score
FOR EACH ROW
BEGIN
    IF :NEW.originality   < 1 OR :NEW.originality   > 10 OR
       :NEW.signification < 1 OR :NEW.signification > 10 OR
       :NEW.quality       < 1 OR :NEW.quality       > 10 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Error: Score values must be between 1 and 10');
    END IF;
END trg_score_range;
/

-- Enforce: funding amount on Sponsor must be positive
CREATE OR REPLACE TRIGGER trg_funding_positive
BEFORE INSERT OR UPDATE ON Sponsor
FOR EACH ROW
BEGIN
    IF :NEW.funding_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20007, 'Error: Funding amount must be positive');
    END IF;
END trg_funding_positive;
/

-- Enforce: non-organizer members can only be linked to one conference
CREATE OR REPLACE TRIGGER trg_non_organizer_one_conference
FOR INSERT ON Organizes
COMPOUND TRIGGER
    TYPE t_id_tbl IS TABLE OF VARCHAR2(20) INDEX BY PLS_INTEGER;
    g_member_ids t_id_tbl;
    g_idx        PLS_INTEGER := 0;

    BEFORE EACH ROW IS
        v_is_organizer CHAR(1);
        v_member_id    VARCHAR2(20);
    BEGIN
        SELECT DEREF(:NEW.member_ref).is_organizer INTO v_is_organizer FROM DUAL;
        IF v_is_organizer = 'N' THEN
            SELECT DEREF(:NEW.member_ref).id INTO v_member_id FROM DUAL;
            g_idx := g_idx + 1;
            g_member_ids(g_idx) := v_member_id;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_conf_count INTEGER;
    BEGIN
        FOR i IN 1..g_idx LOOP
            SELECT COUNT(*) INTO v_conf_count
            FROM (
                SELECT DISTINCT DEREF(conference_ref).acronym
                FROM Organizes
                WHERE DEREF(member_ref).id = g_member_ids(i)
            );
            IF v_conf_count > 1 THEN
                g_member_ids.DELETE;
                g_idx := 0;
                RAISE_APPLICATION_ERROR(-20008, 'Error: Non-organizer member can only be linked to one conference');
            END IF;
        END LOOP;
        g_member_ids.DELETE;
        g_idx := 0;
    END AFTER STATEMENT;
END trg_non_organizer_one_conference;
/

-- ---------------------------------------------------------------
-- 4. PROCEDURES AND FUNCTIONS
-- ---------------------------------------------------------------

-- Register a new conference
CREATE OR REPLACE PROCEDURE proc_register_conference(
    p_acronym IN VARCHAR2,
    p_name    IN VARCHAR2,
    p_url     IN VARCHAR2,
    p_venue   IN VARCHAR2
) AS
BEGIN
    INSERT INTO Conference VALUES (ConferenceTY(p_acronym, p_name, p_url, p_venue));
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20010, 'Error: A conference with acronym ' || p_acronym || ' already exists.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END proc_register_conference;
/

-- Register a program committee member / organizer
CREATE OR REPLACE PROCEDURE proc_register_member(
    p_id           IN VARCHAR2,
    p_name         IN VARCHAR2,
    p_affiliation  IN VARCHAR2,
    p_email        IN VARCHAR2,
    p_phone        IN VARCHAR2,
    p_is_organizer IN CHAR
) AS
BEGIN
    INSERT INTO Member VALUES (MemberTY(p_id, p_name, p_affiliation, p_email, p_phone, p_is_organizer));
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20011, 'Error: A member with ID ' || p_id || ' already exists.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END proc_register_member;
/

-- Register an author (email and phone required)
CREATE OR REPLACE PROCEDURE proc_register_author(
    p_id                IN VARCHAR2,
    p_name              IN VARCHAR2,
    p_affiliation       IN VARCHAR2,
    p_email             IN VARCHAR2,
    p_phone             IN VARCHAR2,
    p_is_contact_author IN CHAR
) AS
BEGIN
    INSERT INTO Author VALUES (AuthorTY(p_id, p_name, p_affiliation, p_email, p_phone, p_is_contact_author));
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20012, 'Error: An author with ID ' || p_id || ' already exists.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END proc_register_author;
/

-- Register a sponsor
CREATE OR REPLACE PROCEDURE proc_register_sponsor(
    p_id             IN VARCHAR2,
    p_name           IN VARCHAR2,
    p_funding_amount IN NUMBER,
    p_funding_date   IN DATE
) AS
BEGIN
    INSERT INTO Sponsor VALUES (SponsorTY(p_id, p_name, p_funding_amount, p_funding_date));
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(-20013, 'Error: A sponsor with ID ' || p_id || ' already exists.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END proc_register_sponsor;
/

-- Submit an article to a conference (creates article, writes, and submits records)
CREATE OR REPLACE PROCEDURE proc_submit_article(
    p_article_id         IN VARCHAR2,
    p_title              IN VARCHAR2,
    p_category           IN VARCHAR2,
    p_research_area      IN VARCHAR2,
    p_contact_author_id  IN VARCHAR2,
    p_conference_acronym IN VARCHAR2
) AS
    v_author_ref     REF AuthorTY;
    v_article_ref    REF ArticleTY;
    v_conference_ref REF ConferenceTY;
BEGIN
    SELECT REF(a) INTO v_author_ref     FROM Author     a WHERE a.id      = p_contact_author_id;
    SELECT REF(c) INTO v_conference_ref FROM Conference c WHERE c.acronym = p_conference_acronym;

    INSERT INTO Article VALUES (
        ArticleTY(p_article_id, p_title, 'pending', 'N', p_category, p_research_area, v_author_ref)
    );
    SELECT REF(ar) INTO v_article_ref FROM Article ar WHERE ar.id = p_article_id;

    INSERT INTO Submits VALUES (v_article_ref, v_conference_ref);
    INSERT INTO Writes  VALUES (v_author_ref,  v_article_ref);
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20009, 'Error: Author or Conference not found.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END proc_submit_article;
/

-- Assign a reviewer (member) to an article
CREATE OR REPLACE PROCEDURE proc_assign_reviewer(
    p_member_id  IN VARCHAR2,
    p_article_id IN VARCHAR2
) AS
    v_member_ref  REF MemberTY;
    v_article_ref REF ArticleTY;
BEGIN
    SELECT REF(m)  INTO v_member_ref  FROM Member  m  WHERE m.id  = p_member_id;
    SELECT REF(ar) INTO v_article_ref FROM Article ar WHERE ar.id = p_article_id;
    INSERT INTO AssignedTo VALUES (v_member_ref, v_article_ref);
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20009, 'Error: Member or Article not found.');
    WHEN OTHERS THEN ROLLBACK; RAISE;
END proc_assign_reviewer;
/

-- Return the average global score for an article
CREATE OR REPLACE FUNCTION func_get_article_scores(
    p_article_id IN VARCHAR2
) RETURN NUMBER AS
    v_avg_score NUMBER;
BEGIN
    SELECT AVG(s.global_score) INTO v_avg_score
    FROM Score s
    WHERE DEREF(s.article).id = p_article_id;
    RETURN v_avg_score;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
    WHEN OTHERS THEN RAISE;
END func_get_article_scores;
/

-- Return accepted articles for a conference ordered by average score descending
CREATE OR REPLACE PROCEDURE proc_get_accepted_articles(
    p_conference_acronym IN  VARCHAR2,
    p_cursor             OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT a.id, a.title, AVG(s.global_score) AS avg_score
        FROM   Article a
        JOIN   Submits su ON DEREF(su.article_ref).id  = a.id
        JOIN   Score   s  ON DEREF(s.article).id       = a.id
        WHERE  DEREF(su.conference_ref).acronym = p_conference_acronym
          AND  a.status = 'accepted'
        GROUP BY a.id, a.title
        ORDER BY avg_score DESC;
END proc_get_accepted_articles;
/
