-- 1. What is the total amount each customer spent at the restaurant?

/* SELECT s.customer_id, SUM(m.price) total_spent_cust
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY sum(m.price) asc; */

-- 2. How many days has each customer visited the restaurant?

/* SELECT customer_id, COUNT( DISTINCT order_date) days_cust_visit
FROM sales
GROUP BY 1; */

-- 3. What was the first item from the menu purchased by each customer?

/* using uncorrelated subqueries */

/* 
select s.customer_id, m.product_name
from sales s
left join menu m
on s.product_id = m.product_id
where s.order_date =(select min(s1.order_date)
	from sales s1
	where s.customer_id = s1.customer_id);
*/

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

/* using correlated subqueries */

/*

SELECT s.customer_id, m.product_name, COUNT(s.customer_id)
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
WHERE s.product_id = ( SELECT product_id
	FROM 
	( SELECT product_id, COUNT(product_id) counts
		FROM sales
		GROUP BY product_id
	) s1
	WHERE counts = (SELECT MAX(counts) 
		FROM (SELECT product_id, COUNT(product_id) counts
		FROM sales
		GROUP BY product_id) s2)
)
GROUP BY 1,2;

*/

-- 5. Which item was the most popular for each customer?

/* 
SELECT s.customer_id, m.product_name, COUNT(s.customer_id)
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
WHERE m.product_name = ANY (SELECT product_name
		FROM (SELECT  m.product_name, COUNT(m.product_name) counts
		FROM sales s1
		LEFT JOIN menu m
		ON s1.product_id = m.product_id
		WHERE s.customer_id = s1.customer_id
		GROUP BY 1) prdt1
		WHERE counts = ( select max(counts)
		       from (SELECT m.product_name, COUNT(m.product_name) counts
		FROM sales s1
		LEFT JOIN menu m
		ON s1.product_id = m.product_id
		WHERE s.customer_id = s1.customer_id
		GROUP BY 1) prdt1

	) )
GROUP BY 1,2 ;

*/

-- 6. Which item was purchased first by the customer after they became a member?

/*
select * 
from 
( 
	select s.customer_id, m.product_name , m_.join_date,
	s.order_date,
	rank() over (partition by s.customer_id order by s.order_date) as position
	from sales s 
	left join menu m
	on s.product_id = m.product_id
	left join members m_
	on s.customer_id = m_.customer_id
	where s.order_date >=m_.join_date
) customer_join_first_purchase
where position = 1; */


-- 7. Which item was purchased just before the customer became a member?

/*
select * 
from ( select s.customer_id, m.product_name , m_.join_date,
	s.order_date,
	rank() over (partition by s.customer_id order by s.order_date desc) as position
	from sales s 
	left join menu m
	on s.product_id = m.product_id
	left join members m_
	on s.customer_id = m_.customer_id
	where s.order_date < m_.join_date
) customer_join_first_purchase
where position = 1;

*/

-- 8. What is the total items and amount spent for each member before they became a member?

-- note 'USING' keyword instead of 'ON'. This works for mysql only.
-- note the joining column must have thesame name and must be enclosed in parenthesis

/* 

SELECT s.customer_id, count(s.product_id) total_item, sum(m.price) amount_spent
from sales s
left join menu m
using (product_id)
left join members m_
using (customer_id)
where s.order_date < m_.join_date
group by 1; 

*/

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

-- use 'CASE' keyword for conditional logic

/*
select customer_id, sum(customer_points) total_point_cust
from ( 
	select s.customer_id, m.product_name, m.price,
	case
	when m.product_name = 'sushi' then m.price * 10 * 2
	else m.price * 10
	end as customer_points
	from sales s
	left join menu m
	on s.product_id = m.product_id
) cust_pts_table
group by 1;

*/

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

-- note use subqueries and 'CASE' to filter out the unneeded records

select customer_id, sum(points) total_points, monthname(order_date) month_
from (
	select * 
	from ( 
		select s.customer_id, m.price,
		m.product_name, s.order_date, m_.join_date, 
		case 
		when s.order_date between m_.join_date and date_add(m_.join_date, interval 6 day) then 1 
		else 0 
		end as cond_date ,
		case 
		when s.order_date between m_.join_date and date_add(m_.join_date, interval 6 day) then m.price *10*2
		else 0
		end as points
		from sales s 
		left join menu m on s.product_id = m.product_id 
		left join members m_ on s.customer_id = m_.customer_id 
	) date_cond
	where cond_date = 1
	union 
	select *
	from ( 
		select s.customer_id,m.price,
		m.product_name, s.order_date, m_.join_date, 
		case 
		when s.order_date < m_.join_date or s.order_date > date_add(m_.join_date, interval 6 day) then 2 
		else 0 
		end as cond_date ,
		case 
		when m.product_name = 'sushi' then m.price * 10 * 2
		else m.price * 10 
		end as points
		from sales s 
		left join menu m on s.product_id = m.product_id 
		left join members m_ on s.customer_id = m_.customer_id 
	) date_cond
	where cond_date = 2
) first_week_sushi_filter
where monthname(order_date) = 'January'
group by 1,3;
