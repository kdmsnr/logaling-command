# -*- coding: utf-8 -*-
#
# Copyright (C) 2011  Miho SUZUKI
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe Logaling::Command do
  let(:base_options) { {"glossary"=>"spec", "source-language"=>"en", "target-language"=>"ja"} }
  let(:command) { Logaling::Command.new([], base_options) }
  let(:glossary_path) { Logaling::Glossary.build_path('spec', 'en', 'ja') }
  let(:target_project_path) { File.join(LOGALING_HOME, "projects", "spec") }
  let(:repository) { Logaling::Repository.new(LOGALING_HOME) }

  before do
    FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
    FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
  end

  describe '#new' do
    before do
      @project_counts = Dir[File.join(LOGALING_HOME, "projects", "*")].size
    end

    context 'when .logaling already exists' do
      before do
        FileUtils.mkdir_p(Logaling::Command::LOGALING_CONFIG)
        @stdout = capture(:stdout) { command.new('spec', 'en', 'ja') }
      end

      it 'print message \"<.logaling path> already exists.\"' do
        @stdout.should == "#{Logaling::Command::LOGALING_CONFIG} already exists.\n"
      end
    end

    context 'when .logaling does not exist' do
      context 'and called with no special option' do
        before do
          command.new('spec', 'en', 'ja')
        end

        it 'should create .logaling' do
          File.exist?(Logaling::Command::LOGALING_CONFIG).should be_true
        end

        it 'should register .logaling as project' do
          File.exist?(target_project_path).should be_true
          Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts + 1
        end
      end

      context "and called with '--no-register=true'" do
        before do
          command.options = base_options.merge("no-register" => true)
          command.new('spec', 'en', 'ja')
        end

        it 'should create .logaling' do
          File.exist?(Logaling::Command::LOGALING_CONFIG).should be_true
        end

        it 'should not register .logaling as project' do
          File.exist?(target_project_path).should be_false
          Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
        end
      end
    end
  end

  describe '#register' do
    before do
      sleep(1)
      @project_counts = Dir[File.join(LOGALING_HOME, "projects", "*")].size
    end

    context "when can not find .logaling" do
      before(:all) do
        FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
        @stdout = capture(:stdout) {command.register}
      end

      it 'register nothing' do
        Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
      end

      it "print message \"Try 'loga new' first.\"" do
        @stdout.should be_include "Try 'loga new' first.\n"
      end
    end

    context 'when find .logaling' do
      before do
        command.new('spec', 'en', 'ja')
        command.register
      end

      it 'register .logaling as project' do
        File.exist?(target_project_path).should be_true
        Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts + 1
      end

      after do
        FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
      end
    end
  end

  describe '#unregister' do
    before do
      @project_counts = Dir[File.join(LOGALING_HOME, "projects", "*")].size
    end

    context "when can not find .logaling" do
      before do
        FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
      end

      context "and call without option" do
        before do
          command.options = base_options.merge("glossary" => nil)
          @stdout = capture(:stdout) {command.unregister}
        end

        it "should print message 'input glossary name ...'" do
          @stdout.should be_include "input glossary name"
        end
      end

      context "and call with option" do
        before do
          command.new('spec', 'en', 'ja')
          @stdout = capture(:stdout) {command.unregister}
        end
        it 'should unregister symlink' do
          Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
        end
      end
    end

    context 'when find .logaling' do
      context 'and .logaling registered' do
        before do
          command.new('spec', 'en', 'ja')
          command.register
          command.unregister
        end

        it 'unregister .logaling' do
          File.exist?(target_project_path).should be_false
          Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
        end
      end

      context "and .logaling is not registered" do
        before do
          command.options = base_options.merge("no-register" => true)
          command.new('spec', 'en', 'ja')
          @stdout = capture(:stdout) {command.unregister}
        end

        it "print message \"<glossary name> is not yet registered.\"" do
          @stdout.should == "spec is not yet registered.\n"
        end
      end
    end
  end

  describe '#config' do
    let(:project_config) { File.join(Logaling::Command::LOGALING_CONFIG, 'config') }
    let(:global_config) { File.join(LOGALING_HOME, 'config') }

    subject { File.read(project_config) }

    context 'with argument "target-language"' do
      before do
        command.new('spec', 'en')
        command.config("target-language", "fr")
      end

      it 'should overwrite target-language' do
        should include "--target-language fr"
      end
    end

    context 'with argument "source-language"' do
      before do
        command.new('spec', 'en')
        command.config("source-language", "ja")
      end

      it 'should overwrite source-language' do
        should include "--source-language ja"
      end
    end

    context 'with argument "--global" and "target-language"' do
      before do
        command.options = base_options.merge("global" => true)
        command.new('spec', 'en')
        command.config("target-language", "ja")
      end

      subject { File.read(global_config) }

      it 'should create LOGALING_HOME/config and write target-language' do
        should include "--target-language ja"
      end

      after do
        FileUtils.remove_entry_secure(global_config, true)
      end
    end
  end

  describe '#add' do
    before do
      command.new('spec', 'en', 'ja')
    end

    context 'with arguments have only bilingual pair' do
      before do
        command.add("spec", "テスト")
      end

      subject { YAML::load_file(glossary_path).find{|h| h["source_term"] == "spec" }}

      it "glossary yaml should contain that term" do
        subject["target_term"].should == "テスト"
      end

      it "term should note have note" do
        subject["note"].should == ""
      end
    end

    context 'with arguments have bilingual pair and note' do
      before do
        command.add("spec", "テスト", "備考")
      end

      subject { YAML::load_file(glossary_path).find{|h| h["source_term"] == "spec" }}

      it "glossary yaml should contain that term" do
        subject["target_term"].should == "テスト"
      end

      it "term should have note" do
        subject["note"].should == "備考"
      end
    end

    context 'project config does not have TARGET-LANGUAGE' do
      let(:command2) { Logaling::Command.new([], {}) }
      let(:global_config) { File.join(LOGALING_HOME, 'config') }
      before do
        FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
        command2.new('spec2', 'en')
        FileUtils.touch(global_config)
        File.open(global_config, "w") do |f| 
          f.puts "--target-language fr"
        end
      end

      context 'but global config have it' do
        before do
          command2.add('config test', '設定ファイルのテスト')
          @stdout = capture(:stdout) {command2.lookup("config")}
        end

        it "should use global config's TARGET-LANGUAGE" do
          @stdout.should include "config"
          @stdout.should include "test"
          @stdout.should include "設定ファイルのテスト"
          @stdout.should include "(spec2)"
        end
      end

      after do
        FileUtils.remove_entry_secure(global_config, true)
      end
    end
  end

  describe "#update" do
    before do
      FileUtils.remove_entry_secure(File.join(LOGALING_HOME, "db", "index_at"), true)
      command.new('spec', 'en', 'ja')
      command.add("spec", "テスト", "備考")
    end

    context "with arguments except note" do
      before do
        command.update("spec", "テスト", "スペック")
        @yaml = YAML::load_file(glossary_path).find{|h| h["source_term"] == "spec" }
      end

      it "term's target_term should be updated" do
        @yaml.should == {"source_term"=>"spec", "target_term"=>"スペック", "note"=>"備考"}
      end
    end

    context 'with exisiting bilingual pair and note' do
      before do
        @stdout = capture(:stdout) { command.update("spec", "テスト", "テスト", "備考") }
      end

      it 'should show error message' do
        @stdout.should include "already exists"
      end
    end

    context 'with existing bilingual pair and different note' do
      before do
        command.update("spec", "テスト", "テスト", "備考だけ書き換え")
        @yaml = YAML::load_file(glossary_path).find{|h| h["source_term"] == "spec" }
      end

      it "should update note" do
        @yaml.should == {"source_term"=>"spec", "target_term"=>"テスト", "note"=>"備考だけ書き換え"}
      end
    end
  end

  describe '#lookup' do
    before do
      command.new('spec', 'en', 'ja')
      command.add("spec", "スペック", "備考")
    end

    context 'with arguments exist term' do
      before do
        @stdout = capture(:stdout) {command.lookup("spec")}
      end

      it 'succeed at find by term without command.index' do
        @stdout.should include "spec"
        @stdout.should include "スペック"
        @stdout.should include "# 備考"
      end
    end
  end

  describe "#delete" do
    before do
      command.new('spec', 'en', 'ja')
      command.add('spec', 'スペック', '備考')
      command.add('user', 'ユーザ', '備考')
      command.add('test', 'てすと1', '備考')
      command.add('test', 'てすと2', '備考')
    end

    context 'with arguments exist term' do
      before do
        command.delete('spec', 'スペック')
        @stdout = capture(:stdout) {command.lookup("spec")}
      end

      it 'should delete the term' do
        @stdout.should_not include "spec : スペック # 備考"
      end
    end

    context 'without target_term' do
      context 'only 1 bilingual pair exist' do
      before do
        command.delete('user')
        @stdout = capture(:stdout) {command.lookup("user")}
      end

      it 'should delete the term' do
        @stdout.should_not include "user : ユーザ # 備考"
      end
      end

      context 'some bilingual pair exist' do
        context "called without '--force=true'" do
          before do
            @stdout = capture(:stdout) {command.delete('test')}
          end

          it "should print usage" do
            @stdout.should == "There are duplicate terms in glossary.\n" +
            "If you really want to delete, please put `loga delete [SOURCE_TERM] --force`\n" +
            " or `loga delete [SOURCE_TERM] [TARGET_TERM]`\n"
          end
        end

        context "and called with '--force=true'" do
          before do
            command.options = base_options.merge("force" => true)
            command.new('spec', 'en', 'ja')
            command.add('term', '用語1', '備考')
            command.add('term', '用語2', '備考')
            command.delete("term")
            @stdout = capture(:stdout) {command.lookup("term")}
          end

          it 'should delete bilingual pairs' do
            @stdout.should_not include "term : 用語1 # 備考"
            @stdout.should_not include "term : 用語2 # 備考"
          end
        end
      end
    end
  end

  describe "#show" do
    let(:csv_path) { File.join(File.dirname(glossary_path), "spec.ja.en.csv") }
    before do
      command.new('spec', 'en', 'ja')
      command.add("spec", "スペック", "備考")
      command.add("spec-test", "スペックてすと", "備考")
      command.add("spec-test-test", "スペックてすとてすと", "備考")

      FileUtils.mkdir_p(File.dirname(glossary_path))
      FileUtils.touch(csv_path)
      File.open(csv_path, "w"){|f| f.puts "test_logaling,テスト"}
    end

    context 'when .logaling exists' do
      before do
        @stdout = capture(:stdout) {command.show}
      end

      it 'should show translation list' do
        @stdout.should include "spec"
        @stdout.should include "spec-test"
        @stdout.should include "spec-test-test"
        @stdout.should_not include "test_logaling"
      end
    end

    context 'with arguments glossary' do
      before do
        command.options = base_options.merge("glossary" => "spec", "source-language" => "ja", "target-language" => "en")
        @stdout = capture(:stdout) {command.show}
      end

      it 'should show translation list' do
        @stdout.should include "test_logaling"
        @stdout.should_not include "spec-test-test"
      end
    end

    after do
      FileUtils.remove_entry_secure(csv_path, true)
    end
  end

  describe '#list' do
    context 'when some glossaries are registered' do
      before do
        command.new('spec', 'en', 'ja')
        @stdout = capture(:stdout) {command.list}
      end

      it 'should list glossaries' do
        @stdout.should include "spec"
      end
    end

    context 'when a glossary is unregistered' do
      before do
        command.new('spec', 'en', 'ja')
        repository.unregister('spec')
        @stdout = capture(:stdout) {command.list}
      end

      it 'should not include unregistered glossary' do
        @stdout.should_not include "spec"
      end
    end
  end

  after do
    FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
    FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
  end
end
