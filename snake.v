import term
import time
import rand
import math
import term.ui as tui

enum Direction {
	pos_x
	neg_x
	pos_y
	neg_y
}

struct Point {
	x int
	y int
}

struct Bounds {
	upper_left  Point
	lower_right Point
}

struct BodyBlock {
mut:
	location         Point
	ticks_to_visible int
}

struct Snake {
	name string
mut:
	body      []BodyBlock
	direction Direction
}

struct Game {
mut:
	snake          Snake
	last_key_press Direction
	is_paused      bool
	has_ended      bool
	points         i64
	tui            &tui.Context = 0
}

const (
	snake_character = 'o'
	rat_character   = '@'
	tick_time_ms    = 10
	paint_factor    = 5
	x_size          = 50
	y_size          = 20
	start_position  = Point{5, 5}
	start_direction = Direction.pos_x
	frame_color     = tui.Color{242, 170, 76}
	backgr_color    = tui.Color{16, 24, 32}
	point_color     = tui.Color{215, 38, 49}
	bounds          = Bounds{
		upper_left: Point{1, 1}
		lower_right: Point{x_size - 1, y_size - 1}
	}
)

fn create_snake(name string, len int) Snake {
	return Snake{
		name: 'main_snake'
		body: create_tail(start_position, len)
		direction: start_direction
	}
}

fn create_tail(head Point, length int) []BodyBlock {
	default_body_block := BodyBlock{
		location: Point{0, 0}
		ticks_to_visible: 0
	}
	mut body := [default_body_block].repeat(length)
	body[0].location = head
	body[0].ticks_to_visible = 0
	mut point := head.add_x(-1)
	for i := 1; i < length; i++ {
		body[i].location = point
		point = point.add_x(-1)
	}
	return body
}

fn (g Game) exit() {
	term.erase_clear()
	term.show_cursor()
	exit(0)
}

fn (s Snake) length() int {
	return s.body.len
}

pub fn (mut snake Snake) change_direction(d Direction) {
	if (snake.direction == .neg_x || snake.direction == .pos_x) && (d == .neg_x || d == .pos_x) {
	} else if (snake.direction == .neg_y || snake.direction == .pos_y)
		&& (d == .neg_y || d == .pos_y) {
	} else {
		snake.direction = d
	}
}

pub fn (mut s Snake) step() {
	// update ticks
	for i := 0; i < s.length(); i++ {
		if s.body[i].ticks_to_visible > 0 {
			s.body[i].ticks_to_visible--
		}
	}
	// update positions
	// everything except the head moves according to the block before it
	for i := s.length() - 1; i >= 1; i-- {
		if s.body[i].is_visible() {
			s.body[i].location = s.body[i - 1].location
		}
	}
	// head moves according to the direction
	s.body[0].location = s.get_next_head_point()
}

fn (s Snake) get_next_head_point() Point {
	match s.direction {
		.pos_x { return s.body[0].location.add_x(1) }
		.neg_x { return s.body[0].location.add_x(-1) }
		.pos_y { return s.body[0].location.add_y(1) }
		.neg_y { return s.body[0].location.add_y(-1) }
	}
	return Point{0, 0}
}

fn (s Snake) get_visible_points() []Point {
	return s.body.filter(it.is_visible()).map(it.location)
}

fn (mut s Snake) check_snake_wrap() {
	head := s.body[0].location
	if head.x <= bounds.upper_left.x {
		s.body[0].location = Point{x_size - 2, s.body[0].location.y}
	} else if head.x >= bounds.lower_right.x {
		s.body[0].location = Point{1, s.body[0].location.y}
	} else if head.y <= bounds.upper_left.y {
		s.body[0].location = Point{s.body[0].location.x, y_size - 2}
	} else if head.y >= bounds.lower_right.y {
		s.body[0].location = Point{s.body[0].location.x, 1}
	}
}

fn (s Snake) is_dead() bool {
	return s.body[0] in s.body[1..]
}

fn (mut s Snake) eat(rat Point) {
	tail := BodyBlock{
		location: rat
		ticks_to_visible: s.length()
	}
	s.body << tail
}

fn get_next_random_point() Point {
	return Point{rand.intn(x_size - 5) + 2, rand.intn(y_size - 5) + 2}
}

fn (s Snake) next_rat() Point {
	mut rat := get_next_random_point()
	locations := s.body.map(it.location)
	for {
		if rat in locations {
			rat = get_next_random_point()
		} else {
			return rat
		}
	}
	return rat
}

fn (b BodyBlock) is_visible() bool {
	return b.ticks_to_visible == 0
}

fn (this BodyBlock) is_equal(that BodyBlock) bool {
	return that.location.is_equal(this.location)
}

fn (p Point) add_x(value int) Point {
	return Point{
		x: p.x + value
		y: p.y
	}
}

fn (p Point) add_y(value int) Point {
	return Point{
		x: p.x
		y: p.y + value
	}
}

pub fn (p Point) str() string {
	return '{$p.x,$p.y}'
}

fn (this Point) is_equal(that Point) bool {
	return this.x == that.x && this.y == that.y
}

pub fn (g Game) should_render_step() bool {
	return !g.is_paused && !g.has_ended
}

pub fn (mut g Game) run() {
	mut i := 0
	mut rat := g.snake.next_rat()
	for {
		if i == paint_factor {
			i = 0

			if g.snake.is_dead() {
				g.has_ended = true
				return
			}

			if g.should_render_step() {
				g.snake.change_direction(g.last_key_press)
				g.snake.step()
				g.snake.check_snake_wrap()
			}

			term.erase_clear()
			if g.snake.body[0].location.is_equal(rat) {
				g.snake.eat(rat)
				rat = g.snake.next_rat()
				g.points += 5
			}
			// paint
			point_list := g.snake.get_visible_points()

			g.tui.set_bg_color(backgr_color)
			g.tui.draw_rect(bounds.upper_left.x, bounds.upper_left.y, bounds.lower_right.x,
				bounds.lower_right.y)
			g.tui.reset_bg_color()
			g.tui.flush()

			print_point_list(mut g, [rat], rat_character)
			print_point_list(mut g, point_list, snake_character)
			print_bounds(mut g)

			if g.is_paused {
				print_pause(mut g)
			}

			print_points(mut g)
		}
		time.sleep(time.millisecond * tick_time_ms)
		i++
	}
}

fn print_point_list(mut g Game, lst []Point, ch string) {
	g.tui.set_bg_color(backgr_color)
	g.tui.set_color(point_color)
	for point in lst {
		g.tui.draw_text(point.x, point.y, term.bold(ch))
	}
	g.tui.reset_color()
}

fn print_line(start Point, end Point, ch string) {
	sx := start.x
	sy := start.y
	ex := end.x
	ey := end.y
	if sx == ex { // move in y
		for i := int(math.min(sy, ey)); i <= int(math.max(sy, ey)); i++ {
			term.set_cursor_position(term.Coord{sx, i})
			println(ch)
		}
	} else if sy == ey { // move in x
		for i := int(math.min(sx, ex)); i <= int(math.max(sx, ex)); i++ {
			term.set_cursor_position(term.Coord{i, sy})
			println(ch)
		}
	} else {
	}
}

fn print_bounds(mut g Game) {
	ul := bounds.upper_left
	lr := bounds.lower_right
	g.tui.set_bg_color(frame_color)
	g.tui.draw_empty_rect(ul.x, ul.y, lr.x, lr.y)
	g.tui.reset_bg_color()
	g.tui.flush()
}

fn print_pause(mut g Game) {
	g.tui.set_color(point_color)
	g.tui.set_bg_color(backgr_color)
	g.tui.draw_text(2, 0, 'PAUSED')
	g.tui.reset_bg_color()
	g.tui.flush()
}

fn print_points(mut g Game) {
	points_str := ' $g.points.str() pts '
	points_len := points_str.len
	g.tui.set_color(point_color)
	g.tui.set_bg_color(backgr_color)
	g.tui.draw_text(x_size - points_len - 1, 0, points_str)
	g.tui.reset_bg_color()
	g.tui.flush()
}

fn main_game() ? {
	mut game := &Game{
		snake: create_snake('käärme', 10)
		last_key_press: .pos_x
		is_paused: false
		has_ended: false
		points: 0
	}

	game.tui = tui.init(
		user_data: game
		event_fn: key_down
		window_title: 'snake!'
		hide_cursor: true
		capture_events: true
		frame_rate: 60
		use_alternate_buffer: false
	)

	go game.run()
	game.tui.run() ?
}

fn key_down(e &tui.Event, mut game Game) {
	if e.typ != .key_down {
		return
	}

	if e.code == .escape || e.code == .q {
		game.exit()
	}

	if game.has_ended {
		time.sleep(time.millisecond * 500)
		game.exit()
	}

	if e.code == .p {
		game.is_paused = !game.is_paused
	}

	if game.is_paused {
		return
	}

	match e.code {
		.up { game.last_key_press = .neg_y }
		.left { game.last_key_press = .neg_x }
		.right { game.last_key_press = .pos_x }
		.down { game.last_key_press = .pos_y }
		else {}
	}
}

fn main() {
	main_game() ?
}
