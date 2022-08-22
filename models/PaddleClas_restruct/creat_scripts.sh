#shell
#只有在模型库增加新的模型，或者改变P0/1结构，执行生成yaml程序

# RedNet  LeViT   GhostNet 有预训练模型
# MobileNetV3 PPLCNet ESNet   ResNet50    ResNet50_vd

#以resnet50为基准，自动从report中获取如下基准值

# ResNet50	6.39329	0	linux单卡训练
# ResNet50	6.50465	0	linux多卡训练
# ResNet50	0.93207	0	linux评估 对于加载预训练模型的要单独评估!!!!!!!!
# ResNet50	8.44204	0	linux单卡训练时 评估
# ResNet50	10.96941	0	linux多卡训练时 评估

# ResNet50	6.43611	0	linux单卡训练_release
# ResNet50	6.62874	0	linux多卡训练_release
# ResNet50	0.93207	0	linux评估 对于加载预训练模型的要单独评估!!!!!!!!
# ResNet50	16.04218	0	linux单卡训练时 评估_release
# ResNet50	7.29234	0	linux多卡训练时 评估_release

# python analysis_html.py #搜集value值  develop 和 release分开统计
#     如何解析？？？现在能把报告转成array
#     从网页解析判断合规，先自己生成后解析   done

# models_list_cls_testP0 弄成循环可配置化  done

# 如果resnet50 release 和 develop一致，其它的不一致怎么办
#     基准值不能只局限于resnet50，也应该可配置化，增加判断条件如果是作为基准值的模型不复制（要用全等号）  done

Repo=${Repo:-PaddleClas}
priority_all=${1:-P0}
echo priority_all
echo ${priority_all}
base_model=ImageNet-ResNet-ResNet50
base_model_latest_name=ResNet50
base_priority=P0
base_model_type="all,ImageNet"
# priority_all='P0' # P0 P1 #还可以控制单独生成某一个yaml models_list_cls_test${某一个或几个模型}
# priority_all='P0 P1' # P0 P1 #还可以控制单独生成某一个yaml models_list_cls_test${某一个或几个模型}
branch='develop release'  # develop release  #顺序不能反 更改分支值，所以下面循环注意是两遍
# read -p "Press enter to continue"  #卡一下

echo base_model
echo ${base_model}
for priority_tmp in $priority_all
do
    cat models_list_cls_test_${priority_tmp} | while read yaml_line
    do
        array=(${yaml_line//\// })
        model_type=${array[2]} #区分 分类、slim、识别等
        model_name=${array[2]} #进行字符串拼接
        if [[ ${1} =~ "PULC" ]];then
            model_type_PULC=${array[3]} #PULC为了区分9中类别单独区分
        fi
        for var in ${array[@]:3}
        do
            array2=(${var//'.yaml'/ })
            model_name=${model_name}-${array2[0]}
        done
        model_latest_name=${array2[0]}


        if [[ ${base_model} == ${model_name} ]]; then
            # echo "#####"
            continue
        else
            # echo "@@@@@"
            cd config
            rm -rf ${model_name}.yaml
            cp -r ${base_model}.yaml ${model_name}.yaml
            sed -i "s|ppcls/configs/ImageNet/ResNet/${base_model_latest_name}.yaml|$yaml_line|g" ${model_name}.yaml #待优化，去掉ResNet
            sed -i s/${base_model}/${model_name}/g ${model_name}.yaml

            # 处理不同的指标 6只是个估算
            params_index=(`cat ../${Repo}/${yaml_line} | grep -n "Metric" | awk -F ":" '{print $1}'`)
            params_word=`sed -n "${params_index[0]},$[${params_index[0]}+6]p" ../${Repo}/${yaml_line}`
            # echo "#### params_index"
            # echo ${params_index}
            # echo ${params_word}
            function change_kpi_tag(){
                #先粗暴的的以行数计算进行替换，暂时报错的eval，写死第9行
                params_index=(`cat ${model_name}.yaml | grep -n "eval_linux" | awk -F ":" '{print $1}'`)
                # echo "#### params_index"
                # echo ${params_index}
                # echo $[${params_index}+9]
                for index_tmp in ${params_index[@]}
                do
                    sed -i "$[${index_tmp}+9]s/loss:/${1}:/" ${model_name}.yaml
                done
            }
            #记录一些特殊规则
            if [[ ${model_name} =~ 'HRNet' ]]; then
                sed -i "s|threshold: 0.0|threshold: 1.0 #|g" ${model_name}.yaml #bodong
                sed -i 's|"="|"-"|g' ${model_name}.yaml
            elif [[ ${model_name} =~ 'LeViT' ]]; then
                sed -i "s|threshold: 0.0|threshold: 1.0 #|g" ${model_name}.yaml #bodong
                sed -i 's|"="|"-"|g' ${model_name}.yaml
            elif [[ ${model_name} =~ 'SwinTransformer' ]]; then
                sed -i "s|threshold: 0.0|threshold: 1.0 #|g" ${model_name}.yaml #bodong
                sed -i 's|"="|"-"|g' ${model_name}.yaml
            elif [[ ${model_name} =~ 'ResNet50_vd' ]]; then
                sed -i "s|ResNet50_vd_vd|ResNet50_vd|g" ${model_name}.yaml #replace
                sed -i "s|ResNet50_vd_vd_vd|ResNet50_vd|g" ${model_name}.yaml #replace
            elif [[ `echo ${params_word} | grep -c "ATTRMetric"` -ne '0' ]] ;then #存在特殊字符
                change_kpi_tag label_f1
            elif [[ `echo ${params_word} | grep -c "Recallk"` -ne '0' ]] ;then #存在特殊字符
                change_kpi_tag recall1
            fi

            #循环修改值
            for branch_tmp in $branch
            do
                # echo branch_tmp
                # echo $branch_tmp
                # echo $branch
                # 在这里还要判断当前模型在report中是否存在，不存在的话就不执行
                sed -i "s|"${base_priority}"|"${priority_tmp}"|g" ${model_name}.yaml #P0/1 #不加\$会报（正常的） sed: first RE may not be empty 加了值不会变
                sed -i "s|"${base_model_type}"|"all,${model_type}"|g" ${model_name}.yaml #修改Imagenet类型
                if [[ -f ../${Repo}_${branch_tmp} ]];then
                    if [[ ! `grep -c "${model_name}" ../${Repo}_${branch_tmp}` -ne '0' ]] ;then #在已有的里面不存在
                        echo "new model :${model_name}"
                    else
                        # echo priority_tmp
                        # echo ${base_priority}
                        # echo ${priority_tmp}
                        # echo $base_model
                        # echo $branch_tmpbranch
                        # grep "${base_model}" ../${Repo}_${branch_tmp}
                        # read -p "Press enter to continue"  #卡一下

                        arr_base=($(echo `grep -w "${base_model}" ../${Repo}_${branch_tmp}` | awk 'BEGIN{FS=",";OFS=" "} {print $1,$2,$3,$4,$5,$6,$7,$8}'))
                        arr_target=($(echo `grep -w "${model_name}" ../${Repo}_${branch_tmp}` | awk 'BEGIN{FS=",";OFS=" "} {print $1,$2,$3,$4,$5,$6,$7,$8}'))
                        # echo arr_base
                        # echo ${arr_base[*]}
                        # echo ${arr_target[*]}
                        num_lisrt='1 2 3 4 5 6 7 8' #一共有8个值需要改变
                        for num_lisrt_tmp in $num_lisrt
                            do
                            # echo ${arr_base[${num_lisrt_tmp}]}
                            # echo ${arr_target[${num_lisrt_tmp}]}
                            sed -i "1,/"${arr_base[${num_lisrt_tmp}]}"/s/"${arr_base[${num_lisrt_tmp}]}"/"${arr_target[${num_lisrt_tmp}]}"/" ${model_name}.yaml
                            #mac命令只替换第一个，linux有所区别需要注意
                            # sed -i "s|"${arr_base[${num_lisrt_tmp}]}"|"${arr_target[${num_lisrt_tmp}]}"|g" ${model_name}.yaml #linux_train_单卡

                            done
                    fi
                else
                    echo "new model :${model_name}"
                fi
            done

            cd ..
        fi

    done

done
