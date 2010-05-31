require 'helper'

class TestDatabase < Test::Unit::TestCase

  attr_accessor :dbh

  def teardown
    @dbh.disconnect if (@dbh and @dbh.connected?)
  end

  def test_01_connect 
    self.dbh = new_database 
    assert(dbh)
    assert_kind_of(RDBI::Driver::SQLite3::Database, dbh)
    assert_kind_of(RDBI::Database, dbh)
    assert_equal(dbh.database_name, ":memory:")
    dbh.disconnect
    assert(!dbh.connected?)
  end

  def test_02_ping
    assert_equal(0, RDBI.ping(:SQLite3, :database => ":memory:"))
    self.dbh = new_database
    assert_equal(0, dbh.ping)
  end

  def test_03_execute
    self.dbh = init_database
    res = dbh.execute("insert into foo (bar) values (?)", 1)
    assert(res)
    assert_kind_of(RDBI::Result, res)
    
    res = dbh.execute("select * from foo")
    assert(res)
    assert_kind_of(RDBI::Result, res)
    assert_equal([["1"]], res.fetch(:all))
  end

  def test_04_prepare
    self.dbh = init_database

    sth = dbh.prepare("insert into foo (bar) values (?)")
    assert(sth)
    assert_kind_of(RDBI::Statement, sth)
    assert_respond_to(sth, :execute)

    5.times { sth.execute(1) }

    assert_equal(dbh.last_statement.object_id, sth.object_id)

    sth2 = dbh.prepare("select * from foo")
    assert(sth)
    assert_kind_of(RDBI::Statement, sth)
    assert_respond_to(sth, :execute)
   
    res = sth2.execute
    assert(res)
    assert_kind_of(RDBI::Result, res)
    assert_equal([["1"]] * 5, res.fetch(:all))

    sth.execute(1)
    
    res = sth2.execute
    assert(res)
    assert_kind_of(RDBI::Result, res)
    assert_equal([["1"]] * 6, res.fetch(:all))

    sth.finish
    sth2.finish
  end

  def test_05_transaction
    self.dbh = init_database

    dbh.transaction do
      assert(dbh.in_transaction?)
      5.times { dbh.execute("insert into foo (bar) values (?)", 1) }
      dbh.rollback
      assert(!dbh.in_transaction?)
    end

    assert(!dbh.in_transaction?)

    assert_equal([], dbh.execute("select * from foo").fetch(:all))
    
    dbh.transaction do 
      assert(dbh.in_transaction?)
      5.times { dbh.execute("insert into foo (bar) values (?)", 1) }
      assert_equal([["1"]] * 5, dbh.execute("select * from foo").fetch(:all))
      dbh.commit
    end

    assert(!dbh.in_transaction?)
    
    assert_equal([["1"]] * 5, dbh.execute("select * from foo").fetch(:all))
  end
end
