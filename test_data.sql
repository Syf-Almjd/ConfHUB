-- ---------------------------------------------------------------
-- Sample Data for ConferenceHub
-- ---------------------------------------------------------------

-- Conferences
INSERT INTO Conference (acronym, name, url, venue)
VALUES ('CVPR2024', 'Conference on Computer Vision and Pattern Recognition',
        'https://cvpr.thecvf.com', 'Seattle, WA');
INSERT INTO Conference (acronym, name, url, venue)
VALUES ('ICSE2024', 'International Conference on Software Engineering',
        'https://conf.researchr.org/home/icse-2024', 'Lisbon, Portugal');

-- Members (is_organizer: Y = organizer, N = reviewer only)
INSERT INTO Member (id, name, affiliation, email, phone, is_organizer)
VALUES ('MEM-001', 'Alice Johnson', 'Stanford University', 'alice@stanford.edu', '555-0101', 'Y');
INSERT INTO Member (id, name, affiliation, email, phone, is_organizer)
VALUES ('MEM-002', 'Bob Smith', 'MIT', 'bob@mit.edu', '555-0102', 'Y');
INSERT INTO Member (id, name, affiliation, email, phone, is_organizer)
VALUES ('MEM-003', 'Carol Davis', 'CMU', 'carol@cmu.edu', '555-0103', 'N');

-- Authors (email and phone required; is_contact_author = 'Y' marks eligible contact authors)
INSERT INTO Author (id, name, affiliation, email, phone, is_contact_author)
VALUES ('AUTH-001', 'Charlie Brown', 'Google AI', 'charlie@google.com', '555-0201', 'Y');
INSERT INTO Author (id, name, affiliation, email, phone, is_contact_author)
VALUES ('AUTH-002', 'Dana White', 'OpenAI', 'dana@openai.com', '555-0202', 'Y');
INSERT INTO Author (id, name, affiliation, email, phone, is_contact_author)
VALUES ('AUTH-003', 'Eve Adams', 'DeepMind', 'eve@deepmind.com', '555-0203', 'N');

-- Sponsors (funding_amount + funding_date are attributes of Sponsor)
INSERT INTO Sponsor (id, name, funding_amount, funding_date)
VALUES ('SPO-001', 'Google Research', 50000, TO_DATE('2024-01-15', 'YYYY-MM-DD'));
INSERT INTO Sponsor (id, name, funding_amount, funding_date)
VALUES ('SPO-002', 'Microsoft Azure', 30000, TO_DATE('2024-02-01', 'YYYY-MM-DD'));
INSERT INTO Sponsor (id, name, funding_amount, funding_date)
VALUES ('SPO-003', 'NSF Grant', 20000, TO_DATE('2024-03-10', 'YYYY-MM-DD'));

-- organizes (N:M): Member organizes Conference
INSERT INTO Organizes (member_ref, conference_ref)
SELECT REF(m), REF(c) FROM Member m, Conference c WHERE m.id = 'MEM-001' AND c.acronym = 'CVPR2024';
INSERT INTO Organizes (member_ref, conference_ref)
SELECT REF(m), REF(c) FROM Member m, Conference c WHERE m.id = 'MEM-002' AND c.acronym = 'CVPR2024';
INSERT INTO Organizes (member_ref, conference_ref)
SELECT REF(m), REF(c) FROM Member m, Conference c WHERE m.id = 'MEM-001' AND c.acronym = 'ICSE2024';
INSERT INTO Organizes (member_ref, conference_ref)
SELECT REF(m), REF(c) FROM Member m, Conference c WHERE m.id = 'MEM-003' AND c.acronym = 'ICSE2024';

-- fund (N:M): Sponsor funds Conference
INSERT INTO Funds (sponsor_ref, conference_ref)
SELECT REF(s), REF(c) FROM Sponsor s, Conference c WHERE s.id = 'SPO-001' AND c.acronym = 'CVPR2024';
INSERT INTO Funds (sponsor_ref, conference_ref)
SELECT REF(s), REF(c) FROM Sponsor s, Conference c WHERE s.id = 'SPO-002' AND c.acronym = 'CVPR2024';
INSERT INTO Funds (sponsor_ref, conference_ref)
SELECT REF(s), REF(c) FROM Sponsor s, Conference c WHERE s.id = 'SPO-003' AND c.acronym = 'ICSE2024';

-- Articles (IS-A hierarchy via category: research_paper, industrial_paper,
--           poster, short_paper, tutorial — no separate sub-tables)
INSERT INTO Article (id, title, status, is_published, category, research_area, contact_author)
VALUES ('ART-001', 'Deep Residual Learning for Image Recognition',
        'accepted', 'Y', 'research_paper', 'Computer Vision',
        (SELECT REF(a) FROM Author a WHERE a.id = 'AUTH-001'));

INSERT INTO Article (id, title, status, is_published, category, research_area, contact_author)
VALUES ('ART-002', 'Generative AI for Industrial Code Synthesis',
        'pending', 'N', 'industrial_paper', 'Machine Learning',
        (SELECT REF(a) FROM Author a WHERE a.id = 'AUTH-002'));

INSERT INTO Article (id, title, status, is_published, category, research_area, contact_author)
VALUES ('ART-003', 'Agile Methods in Large-Scale Projects',
        'rejected', 'N', 'short_paper', 'Software Engineering',
        (SELECT REF(a) FROM Author a WHERE a.id = 'AUTH-001'));

INSERT INTO Article (id, title, status, is_published, category, research_area, contact_author)
VALUES ('ART-004', 'Intro to Transformer Architectures',
        'accepted', 'N', 'tutorial', 'Machine Learning',
        (SELECT REF(a) FROM Author a WHERE a.id = 'AUTH-003'));

INSERT INTO Article (id, title, status, is_published, category, research_area, contact_author)
VALUES ('ART-005', 'Visual Grounding with Diffusion Models',
        'pending', 'N', 'poster', 'Computer Vision',
        (SELECT REF(a) FROM Author a WHERE a.id = 'AUTH-002'));

-- write (N:M): Author writes Article
INSERT INTO Writes (author_ref, article_ref)
SELECT REF(a), REF(art) FROM Author a, Article art WHERE a.id = 'AUTH-001' AND art.id = 'ART-001';
INSERT INTO Writes (author_ref, article_ref)
SELECT REF(a), REF(art) FROM Author a, Article art WHERE a.id = 'AUTH-003' AND art.id = 'ART-001';
INSERT INTO Writes (author_ref, article_ref)
SELECT REF(a), REF(art) FROM Author a, Article art WHERE a.id = 'AUTH-002' AND art.id = 'ART-002';
INSERT INTO Writes (author_ref, article_ref)
SELECT REF(a), REF(art) FROM Author a, Article art WHERE a.id = 'AUTH-001' AND art.id = 'ART-003';
INSERT INTO Writes (author_ref, article_ref)
SELECT REF(a), REF(art) FROM Author a, Article art WHERE a.id = 'AUTH-003' AND art.id = 'ART-004';
INSERT INTO Writes (author_ref, article_ref)
SELECT REF(a), REF(art) FROM Author a, Article art WHERE a.id = 'AUTH-002' AND art.id = 'ART-005';

-- part of / submits (1:N): Article submitted to Conference
INSERT INTO Submits (article_ref, conference_ref)
SELECT REF(art), REF(c) FROM Article art, Conference c WHERE art.id = 'ART-001' AND c.acronym = 'CVPR2024';
INSERT INTO Submits (article_ref, conference_ref)
SELECT REF(art), REF(c) FROM Article art, Conference c WHERE art.id = 'ART-002' AND c.acronym = 'ICSE2024';
INSERT INTO Submits (article_ref, conference_ref)
SELECT REF(art), REF(c) FROM Article art, Conference c WHERE art.id = 'ART-003' AND c.acronym = 'ICSE2024';
INSERT INTO Submits (article_ref, conference_ref)
SELECT REF(art), REF(c) FROM Article art, Conference c WHERE art.id = 'ART-004' AND c.acronym = 'CVPR2024';
INSERT INTO Submits (article_ref, conference_ref)
SELECT REF(art), REF(c) FROM Article art, Conference c WHERE art.id = 'ART-005' AND c.acronym = 'CVPR2024';

-- Reviewer (N:M): AssignedTo — reviewer must organize the article's conference
INSERT INTO AssignedTo (member_ref, article_ref)
SELECT REF(m), REF(art) FROM Member m, Article art WHERE m.id = 'MEM-001' AND art.id = 'ART-001';
INSERT INTO AssignedTo (member_ref, article_ref)
SELECT REF(m), REF(art) FROM Member m, Article art WHERE m.id = 'MEM-002' AND art.id = 'ART-001';

-- Scoring (1:1 per reviewer per article); global_score auto-computed by trigger
-- signification column matches spec naming
INSERT INTO Score (id, originality, signification, quality, comments, reviewer, article)
VALUES ('SCR-001', 9, 10, 9, 'Excellent contribution to the field.',
        (SELECT REF(m) FROM Member m WHERE m.id = 'MEM-001'),
        (SELECT REF(art) FROM Article art WHERE art.id = 'ART-001'));

INSERT INTO Score (id, originality, signification, quality, comments, reviewer, article)
VALUES ('SCR-002', 8, 9, 8, 'Strong results with minor presentation issues.',
        (SELECT REF(m) FROM Member m WHERE m.id = 'MEM-002'),
        (SELECT REF(art) FROM Article art WHERE art.id = 'ART-001'));

COMMIT;
