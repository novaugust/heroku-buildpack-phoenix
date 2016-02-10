function restore_app() {
  if [ -d $(deps_backup_path) ]; then
    cp -pR $(deps_backup_path) ${build_path}/deps
  fi

  if [ $erlang_changed != true ] && [ $elixir_changed != true ]; then
    if [ -d $(build_backup_path) ]; then
      cp -pR $(build_backup_path) ${build_path}/_build
    fi
  fi
}


function copy_hex() {
  mkdir -p ${build_path}/.mix/archives
  mkdir -p ${build_path}/.hex

  if [ -n "$hex_source" ]; then
    hex_file=`basename ${hex_source}`
  else
    # hex file names after elixir-1.1 in the hex-<version>.ez form
    full_hex_file_path=$(ls -t ${HOME}/.mix/archives/hex-*.ez | head -n 1)

    # For older versions of hex which have no version name in file
    if [ -z "$full_hex_file_path" ]; then
      full_hex_file_path=${HOME}/.mix/archives/hex.ez
    fi
  fi

  cp ${HOME}/.hex/registry.ets ${build_path}/.hex/

  output_section "Copying hex from $full_hex_file_path"
  cp $full_hex_file_path ${build_path}/.mix/archives
}


function app_dependencies() {
  # Unset this var so that if the parent dir is a git repo, it isn't detected
  # And all git operations are performed on the respective repos
  local git_dir_value=$GIT_DIR
  unset GIT_DIR

  cd $build_path
  output_section "Fetching app dependencies with mix"
  mix deps.get --only $MIX_ENV || exit 1

  export GIT_DIR=$git_dir_value
  cd - > /dev/null
}


function backup_app() {
  # Delete the previous backups
  rm -rf $(deps_backup_path) $(build_backup_path)

  cp -pR ${build_path}/deps $(deps_backup_path)
  cp -pR ${build_path}/_build $(build_backup_path)
}


function compile_app() {
  local git_dir_value=$GIT_DIR
  unset GIT_DIR

  cd $build_path
  output_section "Compiling"
  PATH=$build_path/.platform_tools/erlang/bin:$PATH
  PATH=$build_path/.platform_tools/elixir/bin:$PATH

  run_compile

  mix deps.clean --unused

  export GIT_DIR=$git_dir_value
  cd - > /dev/null
}

run_compile() {
  local custom_compile="${build_path}/${compile}"

  if [ -f $custom_compile ]; then
    info "Running custom compile"
    source $custom_compile 2>&1 | indent
  else
    info "Running default compile"
    source ${build_pack_path}/${compile} 2>&1 | indent
  fi
}

function write_profile_d_script() {
  output_section "Creating .profile.d with env vars"
  mkdir -p $build_path/.profile.d

  local export_line="export PATH=\$HOME/.platform_tools:\$HOME/.platform_tools/erlang/bin:\$HOME/.platform_tools/elixir/bin:\$HOME/.heroku/node/bin:\$HOME/bin:\$HOME/node_modules/.bin:\$PATH
                     export LC_CTYPE=en_US.utf8
                     export MIX_ENV=${MIX_ENV}"
  echo $export_line >> $build_path/.profile.d/phoenix_buildpack_paths.sh
}
